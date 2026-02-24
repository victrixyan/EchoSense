//
//  MemoryManager.swift
//  EchoSense
//
//  Created by Victrix Yan on 2026/2/23.
//

import Foundation
import Combine
import os.log

/// Manages assessment history and long-term patient data persistence.
/// Integrates with PCDC (Patient-Centered Dementia Care) protocols for tracking agitation trends.
class MemoryManager: ObservableObject {
    private let logger = Logger(subsystem: "com.echosense.memory", category: "persistence")
    private let fileManager = FileManager.default
    
    @Published var assessmentHistory: [AssessmentRecord] = []
    @Published var sessionStartTime: Date = Date()
    
    var currentSession: SessionMemory? {
        SessionMemory(
            patientID: "patient-\(UUID().uuidString.prefix(8))",
            sessionStartTime: sessionStartTime,
            priorAssessments: assessmentHistory,
            demographicNotes: nil,
            clinicalContext: nil
        )
    }
    
    struct AssessmentRecord: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let agitation: Int
        let trend: String
        let keywords: [String]
        let nudges: [String]
        let audioFeatures: [Float]
        let modelVersion: String
        let inferenceTimeMs: Double
        let tokenCount: Int
        let confidence: Float
    }
    
    struct SessionMemory: Codable {
        let patientID: String
        let sessionStartTime: Date
        let priorAssessments: [AssessmentRecord]
        let demographicNotes: String?
        let clinicalContext: String?
    }
    
    init() {
        loadAssessmentHistory()
    }
    
    func addAssessment(
        agitation: Int,
        trend: String,
        keywords: [String],
        nudges: [String],
        audioFeatures: [Float],
        modelVersion: String,
        inferenceTimeMs: Double,
        tokenCount: Int,
        confidence: Float
    ) {
        let record = AssessmentRecord(
            id: UUID(),
            timestamp: Date(),
            agitation: agitation,
            trend: trend,
            keywords: keywords,
            nudges: nudges,
            audioFeatures: audioFeatures,
            modelVersion: modelVersion,
            inferenceTimeMs: inferenceTimeMs,
            tokenCount: tokenCount,
            confidence: confidence
        )
        
        DispatchQueue.main.async {
            self.assessmentHistory.append(record)
            self.saveAssessmentHistory()
        }
    }
    
    private func saveAssessmentHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(assessmentHistory)
            
            let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDir.appendingPathComponent("assessmentHistory.json")
            
            try data.write(to: fileURL, options: .atomic)
            logger.info("Assessment history saved: \(self.assessmentHistory.count) records")
        } catch {
            logger.error("Failed to save assessment history: \(error.localizedDescription)")
        }
    }
    
    private func loadAssessmentHistory() {
        do {
            let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDir.appendingPathComponent("assessmentHistory.json")
            
            guard fileManager.fileExists(atPath: fileURL.path) else {
                logger.info("No existing assessment history file")
                return
            }
            
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let records = try decoder.decode([AssessmentRecord].self, from: data)
            DispatchQueue.main.async {
                self.assessmentHistory = records
                self.logger.info("Loaded \(records.count) assessment records")
            }
        } catch {
            logger.error("Failed to load assessment history: \(error.localizedDescription)")
        }
    }
}
