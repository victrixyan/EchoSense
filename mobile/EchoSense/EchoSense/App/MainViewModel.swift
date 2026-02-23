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

/// Main ViewModel for CoreML model loading and inference orchestration.
/// Coordinates between SpeechManager (audio), SMILEBridge (features), and CoreML model (inference).
class MainViewModel: ObservableObject {
    
    private let logger = Logger(subsystem: "com.echosense.viewmodel", category: "inference")
    private let memoryManager: MemoryManager
    private let speechManager: SpeechManager
    
    @Published var assessmentResult: AssessmentResult?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var modelLoaded = false
    
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
