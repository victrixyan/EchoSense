//
//  DemoTestHarness.swift
//  EchoSense
//
//  Demo testing harness for simulator validation.
//  Injects synthetic dementia speech patterns for UI response testing.
//

import Foundation
import AVFoundation

/// Mock audio samples for simulator testing without actual microphone input.
class DemoTestHarness {
    
    enum DemoScenario: String, CaseIterable {
        case calm = "Calm Baseline"
        case moderate = "Moderate Agitation"
        case escalated = "Escalated State"
        case recovery = "Recovery"
        
        var description: String {
            switch self {
            case .calm:
                return "Patient is calm, speaking clearly about past activities"
            case .moderate:
                return "Patient shows signs of confusion, voice becomes strained, repetitive questions"
            case .escalated:
                return "Patient becomes highly agitated, speaking rapidly, emotional distress evident"
            case .recovery:
                return "Patient gradually calms down after intervention"
            }
        }
    }
    
    /// Generate synthetic biomarker features matching a scenario
    static func generateBiomarkers(for scenario: DemoScenario) -> [Float] {
        switch scenario {
        case .calm:
            // Calm baseline: low variability, clear articulation, steady loudness
            return [
                0.35,    // articulation_variability (low = clear speech)
                15.2,    // spectral_tilt (dB, neutral-upward)
                72.5,    // loudness_mean (dB SPL, conversational)
                2.1,     // loudness_variability (dB, steady)
                0.68,    // intensity_score (0-1, higher = more intense emotion)
                2.3,     // loudness_peaks_per_sec (stable rhythm)
                0.72,    // spectral_clarity_score (0-1, clear)
                0.65,    // voiced_segments_per_sec (normal phonation)
                0.18     // spectral_flux (low = consistent spectrum)
            ]
            
        case .moderate:
            // Moderate agitation: increasing variability, strained voice
            return [
                0.58,    // articulation_variability (higher = unclear)
                22.8,    // spectral_tilt (steeper = tension)
                78.2,    // loudness_mean (increased)
                4.5,     // loudness_variability (fluctuating)
                0.52,    // intensity_score (moderate emotional content)
                3.8,     // loudness_peaks_per_sec (more peaks)
                0.54,    // spectral_clarity_score (degraded)
                0.72,    // voiced_segments_per_sec (maintained)
                0.42     // spectral_flux (increased variability)
            ]
            
        case .escalated:
            // Escalated state: high variability, strained, rapid
            return [
                0.78,    // articulation_variability (very unclear)
                31.5,    // spectral_tilt (severe tension)
                84.8,    // loudness_mean (loudly projected)
                7.2,     // loudness_variability (highly fluctuating)
                0.82,    // intensity_score (high emotional content)
                5.6,     // loudness_peaks_per_sec (rapid peaks)
                0.38,    // spectral_clarity_score (very degraded)
                0.88,    // voiced_segments_per_sec (rapid phonation)
                0.71     // spectral_flux (chaotic spectrum)
            ]
            
        case .recovery:
            // Recovery: decreasing variability, calming pattern
            return [
                0.52,    // articulation_variability (decreasing)
                18.5,    // spectral_tilt (normalizing)
                75.3,    // loudness_mean (settling)
                3.2,     // loudness_variability (stabilizing)
                0.58,    // intensity_score (normalizing emotion)
                2.9,     // loudness_peaks_per_sec (fewer peaks)
                0.62,    // spectral_clarity_score (improving)
                0.70,    // voiced_segments_per_sec (normalizing)
                0.28     // spectral_flux (settling)
            ]
        }
    }
    
    /// Generate expected PCDC model output for a scenario
    static func generateMockPCDCOutput(for scenario: DemoScenario, patientContext: String) -> String {
        _ = patientContext.isEmpty ? "Unknown patient" : patientContext
        
        switch scenario {
        case .calm:
            return """
            {
                "agitation_score": 2,
                "trend": "stable and calm",
                "keywords": ["gardening", "family memories"],
                "recommendations": ["You're at home here with us, and I'm right here with you.", "You always light up when you talk about your garden. What did you enjoy growing?"]
            }
            """
            
        case .moderate:
            return """
            {
                "agitation_score": 6,
                "trend": "increasing confusion",
                "keywords": ["time confusion", "where am I"],
                "recommendations": ["I can see something's troubling you. Take your time; I'm listening.", "You're safe here, and I'm staying with you. We'll work this out together."]
            }
            """
            
        case .escalated:
            return """
            {
                "agitation_score": 9,
                "trend": "heightened emotional distress",
                "keywords": ["anxiety", "distress"],
                "recommendations": ["You seem really upset. I want to understand what's happening for you.", "Let's pause for a moment and take a breath together. You are safe."]
            }
            """
            
        case .recovery:
            return """
            {
                "agitation_score": 4,
                "trend": "calming response to intervention",
                "keywords": ["settling", "comfort"],
                "recommendations": ["You're doing so well. What helped you feel better just now?", "You've shown such strength. Tell me about someone you really loved."]
            }
            """
        }
    }
    
    /// Generate keywords for a demo scenario
    static func generateKeywords(for scenario: DemoScenario) -> [String] {
        switch scenario {
        case .calm:
            return ["gardening", "family memories", "peaceful"]
        case .moderate:
            return ["confusion", "repetition", "where am I"]
        case .escalated:
            return ["anxiety", "distress", "agitation"]
        case .recovery:
            return ["settling", "comfort", "responding"]
        }
    }
    
    /// Generate nudges/recommendations for a demo scenario
    static func generateNudges(for scenario: DemoScenario) -> [String] {
        switch scenario {
        case .calm:
            // Validation therapy: Encourage reminiscence and meaningful conversation
            return [
                "You're at home here with us, and I'm right here with you.",
                "You always light up when you talk about your garden. What did you enjoy growing?"
            ]
        case .moderate:
            // Validation therapy: Acknowledge feelings, offer reassurance
            return [
                "I can see something's troubling you. Take your time; I'm listening.",
                "You're safe here, and I'm staying with you. We'll work this out together."
            ]
        case .escalated:
            // Crisis intervention: Immediate grounding and safety
            return [
                "You seem really upset. I want to understand what's happening for you.",
                "Let's pause for a moment and take a breath together. You are safe."
            ]
        case .recovery:
            // Validation therapy: Reinforce calm, continue meaningful engagement
            return [
                "You're doing so well. What helped you feel better just now?",
                "You've shown such strength. Tell me about someone you really loved."
            ]
        }
    }
    
    
    /// Simulate a full demo sequence for testing UI animations
    static func runDemoSequence(
        onScenarioUpdate: @escaping (DemoScenario, [Float]) -> Void,
        scenario: DemoScenario = .calm
    ) {
        let biomarkers = generateBiomarkers(for: scenario)
        DispatchQueue.main.async {
            onScenarioUpdate(scenario, biomarkers)
        }
    }
    
    /// Generate a complete demo timeline for testing
    static func generateDemoTimeline() -> [(scenario: DemoScenario, delay: TimeInterval)] {
        return [
            (.calm, 0),           // Start calm at t=0s
            (.moderate, 10),      // Begin light agitation at t=10s
            (.escalated, 25),     // Escalate at t=25s
            (.recovery, 40),      // Begin recovery at t=40s
            (.calm, 55)           // Return to baseline at t=55s
        ]
    }
}

/// Demo context examples for testing
struct DemoContextExamples {
    static let examples: [String] = [
        "Mary, 82 years old, lives with family, enjoys gardening and reading family photo albums",
        "John, 76 years old, retired engineer, has early-stage dementia, enjoys conversation about his career",
        "Patricia, 88 years old, widow, lives in care facility, has sun-downing episodes in evening",
        "Robert, 81 years old, long-term dementia, responds well to music and familiar faces",
        "Helen, 85 years old, recently diagnosed, still maintains identity and long-term memories"
    ]
}
