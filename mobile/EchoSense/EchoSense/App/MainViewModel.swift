//
//  MainViewModel.swift
//  EchoSense
//
//  Created by Victrix Yan on 2026/2/23.
//

import Foundation
import CoreML
import Combine
import os.log

/// Main ViewModel orchestrating the complete EchoSense inference pipeline.
/// Manages audio capture, feature extraction, CoreML inference, UI state, and session memory persistence.
/// Runs a 15-20s inference loop with smooth UI animations and PCDC-aligned nudge suggestions.
class MainViewModel: ObservableObject {
    
    private let logger = Logger(subsystem: "com.echosense.viewmodel", category: "inference")
    private let memoryManager: MemoryManager
    private let speechManager: SpeechManager
    
    // MARK: - Published UI State (Observable)
    
    @Published var agitation: Int = 5 {
        didSet {
            if agitation != oldValue {
                lastAgitationUpdateTime = Date()
            }
        }
    }
    @Published var trend: String = "stable"
    @Published var trendFadeOut = false
    @Published var keywords: [String] = []
    @Published var nudges: [String] = []
    @Published var nudgeFadeOut = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var modelLoaded = false
    @Published var currentAssessmentID = UUID()
    
    // MARK: - Timing Control
    
    private var lastAgitationUpdateTime = Date()
    private var agitationUpdateTimer: Timer?
    private var trendUpdateTimer: Timer?
    private var nudgeUpdateTimer: Timer?
    private var recordingTimer: Timer?
    private var inferenceLoopTimer: Timer?
    
    // MARK: - Internal State
    
    private var coreMLModel: MLModel?
    private var smile: SMILEBridge?
    private let inferenceQueue = DispatchQueue(label: "com.echosense.inference", qos: .userInitiated)
    private var assessmentHistory: [AssessmentResult] = []
    private var turnCount = 0
    private var recordingInProgress = false
    
    // MARK: - Assessment Result Structure
    
    struct AssessmentResult: Identifiable {
        let id: UUID = UUID()
        let timestamp: Date = Date()
        let agitation: Int
        let trend: String
        let keywords: [String]
        let nudges: [String]
        let confidence: Float
        let inferenceTimeMs: Double
        let rawOutput: String
    }
    
    // MARK: - Lifecycle
    
    init(
        memoryManager: MemoryManager = MemoryManager(),
        speechManager: SpeechManager = SpeechManager()
    ) {
        self.memoryManager = memoryManager
        self.speechManager = speechManager
        self.smile = SMILEBridge()
        
        loadCoreMLModel()
    }
    
    deinit {
        stopAllTimers()
    }
    
    // MARK: - Model Loading
    
    func loadCoreMLModel() {
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        inferenceQueue.async { [weak self] in
            do {
                guard let modelPath = self?.findModelPath() else {
                    throw ModelError.modelNotFound
                }
                
                let modelURL = URL(fileURLWithPath: modelPath)
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndNeuralEngine
                
                let model = try MLModel(contentsOf: modelURL, configuration: config)
                
                DispatchQueue.main.async {
                    self?.coreMLModel = model
                    self?.modelLoaded = true
                    self?.isProcessing = false
                    self?.logger.info("CoreML model loaded successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to load model: \(error.localizedDescription)"
                    self?.isProcessing = false
                    self?.logger.error("Model loading error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func findModelPath() -> String? {
        let fileManager = FileManager.default
        let documentDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelPath = documentDir.appendingPathComponent("medgemma-1.5-4b.mlpackage").path
        
        if fileManager.fileExists(atPath: modelPath) {
            return modelPath
        }
        
        if let bundlePath = Bundle.main.path(forResource: "medgemma-1.5-4b", ofType: "mlpackage") {
            return bundlePath
        }
        
        return nil
    }
    
    // MARK: - Recording & Inference Loop
    
    func startRecording(withContext patientContext: String) {
        guard modelLoaded else {
            errorMessage = "Model not loaded yet"
            return
        }
        
        recordingInProgress = true
        errorMessage = nil
        speechManager.startRecording()
        
        // Start main inference loop: every 15-20s
        inferenceLoopTimer = Timer.scheduledTimer(withTimeInterval: 18.0, repeats: true) { [weak self] _ in
            self?.runInferenceStep(patientContext: patientContext)
        }
        
        logger.info("Recording and inference loop started")
    }
    
    func stopRecording() {
        recordingInProgress = false
        stopAllTimers()
        
        if let audioData = speechManager.stopRecording() {
            logger.info("Recording stopped: \(audioData.duration)s, \(audioData.pcmBuffer.count) samples")
        }
    }
    
    // MARK: - Inference Pipeline (Phase 5 Core)
    
    private func runInferenceStep(patientContext: String) {
        guard let audioData = speechManager.stopRecording() else { return }
        
        DispatchQueue.main.async { self.isProcessing = true }
        
        inferenceQueue.async { [weak self] in
            self?.performInference(
                audioData: audioData,
                patientPrompt: patientContext
            )
        }
    }
    
    private func performInference(
        audioData: SpeechManager.AudioRecordingData,
        patientPrompt: String
    ) {
        let startTime = Date()
        
        do {
            // 1. Extract acoustic features
            guard let smile = smile else { throw ModelError.bridgeNotInitialized }
            smile.initialize(Int32(audioData.sampleRate))
            
            let audioBuffer = audioData.pcmBuffer
            let features = smile.extractFeaturesNormalized(audioBuffer, Int32(audioBuffer.count))
            
            logger.info("Extracted \(features.count) acoustic features")
            
            // 2. Build PCDC-enhanced prompt with memory and context
            let pcdc_prompt = buildPCDCPrompt(
                basePrompt: patientPrompt,
                audioFeatures: features,
                sessionMemory: memoryManager.currentSession
            )
            
            // 3. Create CoreML inputs
            let featureProvider = try createFeatureProvider(
                promptText: pcdc_prompt,
                biomarkers: features
            )
            
            // 4. Run CoreML inference
            guard let model = coreMLModel else { throw ModelError.modelNotLoaded }
            let output = try model.prediction(from: featureProvider)
            
            // 5. Extract JSON output
            var jsonString = ""
            if let outputValue = output.featureValue(for: "json_output")?.stringValue {
                jsonString = outputValue
            }
            
            let inferenceTime = Date().timeIntervalSince(startTime) * 1000
            let result = parseInferenceOutput(
                jsonOutput: jsonString,
                audioFeatures: features,
                inferenceTimeMs: inferenceTime
            )
            
            // 6. Update UI with smooth animations
            DispatchQueue.main.async {
                self.updateUIStates(with: result)
                self.assessmentHistory.append(result)
                self.turnCount += 1
                self.isProcessing = false
                
                // Auto-save every 5 turns
                if self.turnCount % 5 == 0 {
                    self.memoryManager.addAssessment(
                        agitation: result.agitation,
                        trend: result.trend,
                        keywords: result.keywords,
                        nudges: result.nudges,
                        audioFeatures: features,
                        modelVersion: "medgemma-1.5-4b",
                        inferenceTimeMs: inferenceTime,
                        tokenCount: jsonString.split(separator: " ").count,
                        confidence: result.confidence
                    )
                }
                
                self.logger.info("Assessment complete: agitation=\(result.agitation), trend=\(result.trend)")
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Inference failed: \(error.localizedDescription)"
                self.isProcessing = false
                self.logger.error("Inference error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - UI State Updates (Phase 5: Smooth Animations)
    
    private func updateUIStates(with result: AssessmentResult) {
        // Update agitation (smooth lerp over 10s via Timer animation)
        let oldAgitation = agitation
        let newAgitation = result.agitation
        
        if newAgitation != oldAgitation {
            animateAgitation(from: oldAgitation, to: newAgitation, duration: 10.0)
        }
        
        // Update trend (60s display with fade in/out)
        trend = result.trend
        trendFadeOut = false
        
        trendUpdateTimer?.invalidate()
        trendUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.trendFadeOut = true
                }
            }
        }
        
        // Update keywords (static unless new emerge)
        if !result.keywords.isEmpty {
            let newKeywords = result.keywords
            if newKeywords != keywords {
                keywords = newKeywords
            }
        }
        
        // Update nudges (rolling 15-20s fade with escalation override)
        if !result.nudges.isEmpty {
            let shouldOverride = result.agitation >= 7  // Escalation threshold
            
            if shouldOverride || nudges.isEmpty {
                nudges = result.nudges
                nudgeFadeOut = false
                
                nudgeUpdateTimer?.invalidate()
                nudgeUpdateTimer = Timer.scheduledTimer(
                    withTimeInterval: shouldOverride ? 10.0 : 18.0,
                    repeats: false
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.3)) {
                            self?.nudgeFadeOut = true
                        }
                    }
                }
            }
        }
        
        currentAssessmentID = result.id
    }
    
    // MARK: - Agitation Animation (Smooth 10s Lerp)
    
    private func animateAgitation(from: Int, to: Int, duration: TimeInterval) {
        let startTime = Date()
        let startValue = Float(from)
        let endValue = Float(to)
        let range = endValue - startValue
        
        agitationUpdateTimer?.invalidate()
        agitationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            
            let interpolated = startValue + range * Float(progress)
            DispatchQueue.main.async {
                self?.agitation = Int(round(interpolated))
            }
            
            if progress >= 1.0 {
                timer.invalidate()
            }
        }
    }
    
    // MARK: - PCDC Prompt Building
    
    private func buildPCDCPrompt(
        basePrompt: String,
        audioFeatures: [Float],
        sessionMemory: MemoryManager.SessionMemory?
    ) -> String {
        var prompt = ""
        
        if let session = sessionMemory {
            prompt += "Patient Profile: \(session.patientID)\n"
            if !session.priorAssessments.isEmpty {
                let recentAgitations = session.priorAssessments.suffix(3).map { $0.agitation }
                let trend = recentAgitations.last ?? 5 > recentAgitations.first ?? 5 ? "increasing" : "stable"
                prompt += "Recent Trend: \(trend)\n"
            }
        }
        
        prompt += "Patient Context: \(basePrompt)\n"
        prompt += "Voice Features (normalized): "
        prompt += audioFeatures.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: ", ")
        prompt += "\n"
        
        prompt += "Task: Rate patient agitation (0-10), describe trend, identify keywords, suggest PCDC responses.\n"
        prompt += "Output JSON ONLY: {\"agitation\":5,\"trend\":\"stable\",\"keywords\":[],\"nudges\":[]}\n"
        
        return prompt
    }
    
    // MARK: - Feature Provider Creation
    
    private func createFeatureProvider(
        promptText: String,
        biomarkers: [Float]
    ) throws -> MLFeatureProvider {
        var features = [String: MLFeatureValue]()
        
        features["prompt_text"] = MLFeatureValue(string: promptText)
        
        guard biomarkers.count >= 9 else {
            throw ModelError.invalidAudioFeatures
        }
        
        let shape: [NSNumber] = [9]
        let biomarkerValue = try MLMultiArray(
            dataPointer: UnsafeMutablePointer(mutating: biomarkers),
            shape: shape,
            dataType: .float32,
            strides: [1]
        )
        features["biomarkers"] = MLFeatureValue(multiArray: biomarkerValue)
        
        return try MLDictionaryFeatureProvider(dictionary: features)
    }
    
    // MARK: - Output Parsing
    
    private func parseInferenceOutput(
        jsonOutput: String,
        audioFeatures: [Float],
        inferenceTimeMs: Double
    ) -> AssessmentResult {
        var agitation = 5
        var trend = "stable"
        var keywords = [String]()
        var nudges = [String]()
        var confidence = 0.75
        
        if let data = jsonOutput.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let ag = json["agitation"] as? Int {
                agitation = min(10, max(0, ag))
            }
            if let tr = json["trend"] as? String {
                trend = tr
            }
            if let kw = json["keywords"] as? [String] {
                keywords = Array(kw.prefix(3))
            }
            if let nu = json["nudges"] as? [String] {
                nudges = Array(nu.prefix(2))
            }
            if let conf = json["confidence"] as? NSNumber {
                confidence = Float(truncating: conf)
            }
        }
        
        // Fallback: Infer from audio features if JSON parsing fails
        if keywords.isEmpty && audioFeatures.count >= 9 {
            if audioFeatures[3] > 0.5 {  // High loudness variability
                keywords.append("vocal_variation")
            }
            if audioFeatures[0] > 0.3 {  // High articulation variability
                keywords.append("speech_clarity")
            }
        }
        
        return AssessmentResult(
            agitation: agitation,
            trend: trend,
            keywords: keywords,
            nudges: nudges,
            confidence: confidence,
            inferenceTimeMs: inferenceTimeMs,
            rawOutput: jsonOutput
        )
    }
    
    // MARK: - Timer Management
    
    private func stopAllTimers() {
        agitationUpdateTimer?.invalidate()
        trendUpdateTimer?.invalidate()
        nudgeUpdateTimer?.invalidate()
        recordingTimer?.invalidate()
        inferenceLoopTimer?.invalidate()
    }
    
    // MARK: - Error Types
    
    enum ModelError: LocalizedError {
        case modelNotFound
        case modelNotLoaded
        case bridgeNotInitialized
        case invalidAudioFeatures
        
        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "CoreML model file not found"
            case .modelNotLoaded:
                return "Model not loaded yet"
            case .bridgeNotInitialized:
                return "OpenSMILE bridge initialization failed"
            case .invalidAudioFeatures:
                return "Invalid audio features extracted"
            }
        }
    }
}

    
    private var coreMLModel: MLModel?
    private var smile: SMILEBridge?
    private let inferenceQueue = DispatchQueue(label: "com.echosense.inference", qos: .userInitiated)
    
    // MARK: - Inference Result
    
    struct AssessmentResult: Identifiable {
        let id = UUID()
        let agitation: Int  // 0-10
        let trend: String
        let keywords: [String]
        let nudges: [String]
        let confidence: Float
        let inferenceTimeMs: Double
        let rawOutput: String
    }
    
    // MARK: - Lifecycle
    
    init(
        memoryManager: MemoryManager = MemoryManager(),
        speechManager: SpeechManager = SpeechManager()
    ) {
        self.memoryManager = memoryManager
        self.speechManager = speechManager
        self.smile = SMILEBridge()
        
        loadCoreMLModel()
    }
    
    // MARK: - Model Loading
    
    func loadCoreMLModel() {
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        inferenceQueue.async { [weak self] in
            do {
                // Locate medgemma-1.5-4b.mlpackage in app bundle or documents
                guard let modelPath = self?.findModelPath() else {
                    throw ModelError.modelNotFound
                }
                
                let modelURL = URL(fileURLWithPath: modelPath)
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndNeuralEngine
                
                let model = try MLModel(contentsOf: modelURL, configuration: config)
                
                DispatchQueue.main.async {
                    self?.coreMLModel = model
                    self?.modelLoaded = true
                    self?.isProcessing = false
                    self?.logger.info("CoreML model loaded successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to load model: \(error.localizedDescription)"
                    self?.isProcessing = false
                    self?.logger.error("Model loading error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func findModelPath() -> String? {
        let fileManager = FileManager.default
        let documentDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelPath = documentDir.appendingPathComponent("medgemma-1.5-4b.mlpackage").path
        
        if fileManager.fileExists(atPath: modelPath) {
            return modelPath
        }
        
        // Fallback: check app bundle
        if let bundlePath = Bundle.main.path(forResource: "medgemma-1.5-4b", ofType: "mlpackage") {
            return bundlePath
        }
        
        return nil
    }
    
    // MARK: - Inference Pipeline
    
    func runAssessment(patientPrompt: String) {
        guard let audioData = speechManager.stopRecording() else {
            errorMessage = "No audio recorded"
            return
        }
        
        guard modelLoaded else {
            errorMessage = "Model not loaded"
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.errorMessage = nil
        }
        
        inferenceQueue.async { [weak self] in
            self?.performInference(
                audioData: audioData,
                patientPrompt: patientPrompt
            )
        }
    }
    
    private func performInference(audioData: SpeechManager.AudioRecordingData, patientPrompt: String) {
        let startTime = Date()
        
        do {
            // 1. Extract acoustic features via SMILEBridge
            guard let smile = smile else { throw ModelError.bridgeNotInitialized }
            smile.initialize(Int32(audioData.sampleRate))
            
            let audioBuffer = audioData.pcmBuffer
            let features = smile.extractFeaturesNormalized(audioBuffer, Int32(audioBuffer.count))
            
            logger.info("Extracted \(features.count) acoustic features")
            
            // 2. Prepare CoreML inputs
            let featureProvider = try createFeatureProvider(
                promptText: patientPrompt,
                biomarkers: features
            )
            
            // 3. Run CoreML inference
            guard let model = coreMLModel else { throw ModelError.modelNotLoaded }
            let output = try model.prediction(from: featureProvider)
            
            // 4. Parse PCDC output
            var jsonString = ""
            if let outputValue = output.featureValue(for: "json_output")?.stringValue {
                jsonString = outputValue
            }
            
            let result = parseInferenceOutput(
                jsonOutput: jsonString,
                audioFeatures: features,
                inferenceTimeMs: Date().timeIntervalSince(startTime) * 1000
            )
            
            // 5. Store in memory management and update UI
            DispatchQueue.main.async {
                self.assessmentResult = result
                self.isProcessing = false
                
                self.memoryManager.addAssessment(
                    agitation: result.agitation,
                    trend: result.trend,
                    keywords: result.keywords,
                    nudges: result.nudges,
                    audioFeatures: features,
                    modelVersion: "medgemma-1.5-4b",
                    inferenceTimeMs: result.inferenceTimeMs,
                    tokenCount: jsonString.split(separator: " ").count,
                    confidence: result.confidence
                )
                
                self.logger.info("Assessment complete: agitation=\(result.agitation), time=\(result.inferenceTimeMs)ms")
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Inference failed: \(error.localizedDescription)"
                self.isProcessing = false
                self.logger.error("Inference error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Feature Provider Creation
    
    private func createFeatureProvider(
        promptText: String,
        biomarkers: [Float]
    ) throws -> MLFeatureProvider {
        var features = [String: MLFeatureValue]()
        
        // Add prompt text input
        features["prompt_text"] = MLFeatureValue(string: promptText)
        
        // Add biomarkers (9 features) as multi-array
        guard biomarkers.count >= 9 else {
            throw ModelError.invalidAudioFeatures
        }
        
        let shape: [NSNumber] = [9]
        let biomarkerValue = try MLMultiArray(dataPointer: UnsafeMutablePointer(mutating: biomarkers),
                                            shape: shape,
                                            dataType: .float32,
                                            strides: [1])
        features["biomarkers"] = MLFeatureValue(multiArray: biomarkerValue)
        
        return try MLDictionaryFeatureProvider(dictionary: features)
    }
    
    // MARK: - Output Parsing
    
    private func parseInferenceOutput(
        jsonOutput: String,
        audioFeatures: [Float],
        inferenceTimeMs: Double
    ) -> AssessmentResult {
        var agitation = 5
        var trend = "stable"
        var keywords = ["speech quality normal"]
        var nudges = [String]()
        var confidence = 0.75
        
        // Parse JSON output (simplified parser for PCDC format)
        if let data = jsonOutput.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let ag = json["agitation"] as? Int {
                agitation = min(10, max(0, ag))  // Clamp to 0-10
            }
            if let tr = json["trend"] as? String {
                trend = tr
            }
            if let kw = json["keywords"] as? [String] {
                keywords = Array(kw.prefix(3))
            }
            if let nu = json["nudges"] as? [String] {
                nudges = Array(nu.prefix(2))
            }
            if let conf = json["confidence"] as? NSNumber {
                confidence = Float(truncating: conf)
            }
        }
        
        // Infer trend from audio features if not provided
        if audioFeatures.count >= 9 {
            let loudnessVariability = audioFeatures[3]
            let articulationVar = audioFeatures[0]
            
            if loudnessVariability > 0.5 || articulationVar > 0.4 {
                trend = "increasing"
                agitation = min(10, agitation + 2)
            }
        }
        
        return AssessmentResult(
            agitation: agitation,
            trend: trend,
            keywords: keywords,
            nudges: nudges,
            confidence: confidence,
            inferenceTimeMs: inferenceTimeMs,
            rawOutput: jsonOutput
        )
    }
    
    // MARK: - State Management
    
    enum ModelError: LocalizedError {
        case modelNotFound
        case modelNotLoaded
        case bridgeNotInitialized
        case invalidAudioFeatures
        
        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "CoreML model file not found"
            case .modelNotLoaded:
                return "Model not loaded yet"
            case .bridgeNotInitialized:
                return "OpenSMILE bridge initialization failed"
            case .invalidAudioFeatures:
                return "Invalid audio features extracted"
            }
        }
    }
}
