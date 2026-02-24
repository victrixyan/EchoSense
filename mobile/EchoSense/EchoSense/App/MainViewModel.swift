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
import SwiftUI

/// Main ViewModel orchestrating the complete EchoSense inference pipeline.
/// Manages audio capture, feature extraction, CoreML inference, UI state, and session memory persistence.
/// Runs a 15-20s inference loop with smooth UI animations and PCDC-aligned nudge suggestions.
class MainViewModel: ObservableObject {
    
    private let logger = Logger(subsystem: "com.echosense.viewmodel", category: "inference")
    private let memoryManager: MemoryManager
    let speechManager: SpeechManager
    
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
    private var demoMode = false // Enable demo inference when CoreML model unavailable
    private let inferenceQueue = DispatchQueue(label: "com.echosense.inference", qos: .userInitiated)
    private var assessmentHistory: [AssessmentResult] = []
    private var turnCount = 0
    private var recordingInProgress = false
    private var currentDemoScenario = DemoTestHarness.DemoScenario.calm
    
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
                    // Enable demo mode instead of throwing error
                    DispatchQueue.main.async {
                        self?.demoMode = true
                        self?.modelLoaded = true
                        self?.isProcessing = false
                        self?.errorMessage = "(Demo Mode - CoreML model not found, using synthetic inference)"
                        self?.logger.info("Demo mode enabled - using synthetic inference")
                    }
                    return
                }
                
                let modelURL = URL(fileURLWithPath: modelPath)
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndNeuralEngine
                
                let model = try MLModel(contentsOf: modelURL, configuration: config)
                
                DispatchQueue.main.async {
                    self?.coreMLModel = model
                    self?.demoMode = false
                    self?.modelLoaded = true
                    self?.isProcessing = false
                    self?.errorMessage = nil
                    self?.logger.info("CoreML model loaded successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    // Fall back to demo mode on error
                    self?.demoMode = true
                    self?.modelLoaded = true
                    self?.isProcessing = false
                    self?.errorMessage = "(Demo Mode - \(error.localizedDescription))"
                    self?.logger.error("Model loading error, falling back to demo mode: \(error.localizedDescription)")
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
            let featuresNSNumbers = smile.extractFeaturesNormalized(audioBuffer, length: Int32(audioBuffer.count))
            let features = featuresNSNumbers.compactMap { $0.floatValue }
            
            logger.info("Extracted \(features.count) acoustic features")
            
            let inferenceTime = Date().timeIntervalSince(startTime) * 1000
            
            // Demo mode vs real inference
            let result: AssessmentResult
            
            if demoMode {
                // Use synthetic demo inference
                let biomarkers = DemoTestHarness.generateBiomarkers(for: currentDemoScenario)
                let mockOutput = DemoTestHarness.generateMockPCDCOutput(
                    for: currentDemoScenario,
                    patientContext: patientPrompt
                )
                result = AssessmentResult(
                    agitation: extractAgitationScores(from: biomarkers).0,
                    trend: determineTrend(from: biomarkers),
                    keywords: DemoTestHarness.generateKeywords(for: currentDemoScenario),
                    nudges: DemoTestHarness.generateNudges(for: currentDemoScenario),
                    confidence: 0.85,
                    inferenceTimeMs: inferenceTime,
                    rawOutput: mockOutput
                )
                
                // Rotate through demo scenarios
                let scenarios = DemoTestHarness.DemoScenario.allCases
                if let currentIndex = scenarios.firstIndex(of: currentDemoScenario) {
                    let nextIndex = (currentIndex + 1) % scenarios.count
                    currentDemoScenario = scenarios[nextIndex]
                }
                
            } else {
                // Real CoreML inference
                let pcdc_prompt = buildPCDCPrompt(
                    basePrompt: patientPrompt,
                    audioFeatures: features,
                    sessionMemory: memoryManager.currentSession
                )
                
                let featureProvider = try createFeatureProvider(
                    promptText: pcdc_prompt,
                    biomarkers: features
                )
                
                guard let model = coreMLModel else { throw ModelError.modelNotLoaded }
                let output = try model.prediction(from: featureProvider)
                
                var jsonString = ""
                if let outputValue = output.featureValue(for: "json_output")?.stringValue {
                    jsonString = outputValue
                }
                
                result = parseInferenceOutput(
                    jsonOutput: jsonString,
                    audioFeatures: features,
                    inferenceTimeMs: inferenceTime
                )
            }
            
            // 6. Update UI with smooth animations
            DispatchQueue.main.async {
                self.updateUIStates(with: result)
                self.assessmentHistory.append(result)
                self.turnCount += 1
                self.isProcessing = false
                
                // Auto-save every 5 turns
                if self.turnCount % 5 == 0 {
                    let features = self.demoMode ?
                        DemoTestHarness.generateBiomarkers(for: self.currentDemoScenario) :
                        [Float]()
                    self.memoryManager.addAssessment(
                        agitation: result.agitation,
                        trend: result.trend,
                        keywords: result.keywords,
                        nudges: result.nudges,
                        audioFeatures: features,
                        modelVersion: self.demoMode ? "demo-v1" : "medgemma-1.5-4b",
                        inferenceTimeMs: result.inferenceTimeMs,
                        tokenCount: result.rawOutput.split(separator: " ").count,
                        confidence: result.confidence
                    )
                }
                
                self.logger.info("Assessment complete: agitation=\(result.agitation), trend=\(result.trend), demoMode=\(self.demoMode)")
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
                self?.trendFadeOut = true
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
                        self?.nudgeFadeOut = true
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
        
        let shape: [NSNumber] = [NSNumber(value: 9)]
        let biomarkerValue = try MLMultiArray(shape: shape, dataType: .float32)
        
        // Copy biomarker data into MLMultiArray
        for i in 0..<min(9, biomarkers.count) {
            biomarkerValue[i] = NSNumber(value: biomarkers[i])
        }
        
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
        var confidence: Float = 0.75
        
        if let data = jsonOutput.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let ag = json["agitation"] as? Int {
                agitation = min(9, max(0, ag))
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
    
    // MARK: - Demo Mode Helpers
    
    /// Extract agitation score from biomarker features
    private func extractAgitationScores(from biomarkers: [Float]) -> (Int, Float) {
        guard biomarkers.count >= 9 else { return (5, 0.5) }
        
        // Map biomarkers to agitation (0-10 scale)
        let articulation = biomarkers[0]      // 0-1: higher = more unclear
        let spectralTilt = biomarkers[1]      // dB: higher = more tension
        let loudnessVar = biomarkers[3]       // dB: higher = more variable
        let emotionalScore = biomarkers[4]    // 0-1: higher = more emotional
        let spectralFlux = biomarkers[8]      // 0-1: higher = more chaotic
        
        // Weighted combination for agitation
        let score = (articulation * 2.0 + spectralTilt / 20.0 + loudnessVar / 3.0 + 
                     emotionalScore * 4.0 + spectralFlux * 2.0) / 10.0
        let agitation = Int(min(9, max(0, score * 10)))
        let confidence = max(0.5, articulation + spectralFlux) / 2.0
        
        return (agitation, Float(confidence))
    }
    
    /// Determine trend from biomarker features
    private func determineTrend(from biomarkers: [Float]) -> String {
        guard biomarkers.count >= 9 else { return "stable" }
        
        let loudnessVar = biomarkers[3]
        let emotionalScore = biomarkers[4]
        let spectralFlux = biomarkers[8]
        
        if loudnessVar > 5.0 && emotionalScore > 0.7 {
            return "escalating agitation"
        } else if loudnessVar < 2.0 && emotionalScore < 0.4 {
            return "calm and stable"
        } else if spectralFlux > 0.6 {
            return "chaotic speech patterns"
        } else if emotionalScore > 0.6 {
            return "heightened emotion"
        } else {
            return "stable"
        }
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
