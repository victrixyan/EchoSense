//
//  MainView.swift
//  EchoSense
//
//  Created by Victrix Yan on 2026/2/23.
//

import SwiftUI
import AVFoundation

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @State var userPrompt: String = ""
    @State var recordingDuration: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("EchoSense Dementia Risk Assessment")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Real-time acoustic analysis with MedGemma-1.5-4b")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Model Status
                HStack {
                    Image(systemName: viewModel.modelLoaded ? "checkmark.circle.fill" : "circle.fill")
                        .foregroundColor(viewModel.modelLoaded ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Status")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(viewModel.modelLoaded ? "CoreML model loaded" : "Loading model...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Patient Prompt Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Patient Context")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextEditor(text: $userPrompt)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                        .border(Color(.systemGray4), width: 1)
                        .placeholder(when: userPrompt.isEmpty) {
                            Text("Enter patient context, prior assessment notes, or clinical observations...")
                                .foregroundColor(.gray)
                                .padding(12)
                        }
                }
                
                // Recording Controls
                VStack(spacing: 12) {
                    if viewModel.isProcessing {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing audio and running inference...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBlue).opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    // Record Button
                    Button(action: toggleRecording) {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            Text(viewModel.speechManager.isRecording ? "Stop Recording" : "Start Recording")
                            Spacer()
                            if viewModel.speechManager.isRecording {
                                Text(String(format: "%.1f s", viewModel.speechManager.recordingDuration))
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(viewModel.speechManager.isRecording ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .fontWeight(.semibold)
                    }
                    .disabled(!viewModel.modelLoaded || viewModel.isProcessing)
                }
                
                // Assessment Result
                if let result = viewModel.assessmentResult {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Assessment Result")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("Time: \(String(format: "%.0f", result.inferenceTimeMs))ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Agitation Score
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Agitation Score")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(result.agitation)/10")
                                    .font(.headline)
                                    .foregroundColor(agitationColor(result.agitation))
                            }
                            
                            ProgressView(value: Double(result.agitation) / 10.0)
                                .tint(agitationColor(result.agitation))
                        }
                        
                        // Trend
                        HStack {
                            Text("Trend:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(result.trend.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(trendColor(result.trend).opacity(0.2))
                                .foregroundColor(trendColor(result.trend))
                                .cornerRadius(4)
                        }
                        
                        // Keywords
                        if !result.keywords.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Keywords:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                FlowLayout(spacing: 6) {
                                    ForEach(result.keywords, id: \.self) { keyword in
                                        Text(keyword)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemBlue).opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        
                        // Nudges
                        if !result.nudges.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PCDC Nudges:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                ForEach(result.nudges, id: \.self) { nudge in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text(nudge)
                                            .font(.caption)
                                            .lineLimit(3)
                                    }
                                }
                            }
                        }
                        
                        // Confidence
                        HStack {
                            Text("Confidence:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(String(format: "%.0f%%", result.confidence * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGreen).opacity(0.05))
                    .border(Color(.systemGreen).opacity(0.2), width: 1)
                    .cornerRadius(8)
                }
                
                // Error Message
                if let error = viewModel.errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemRed).opacity(0.1))
                    .cornerRadius(6)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("EchoSense")
        }
        .onAppear {
            requestMicrophonePermission()
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleRecording() {
        if viewModel.speechManager.isRecording {
            viewModel.runAssessment(patientPrompt: userPrompt)
        } else {
            viewModel.speechManager.startRecording()
        }
    }
    
    private func requestMicrophonePermission() {
        viewModel.speechManager.requestMicrophonePermission { granted in
            if !granted {
                viewModel.errorMessage = "Microphone access required for recording"
            }
        }
    }
    
    private func agitationColor(_ score: Int) -> Color {
        if score <= 3 {
            return .green
        } else if score <= 6 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func trendColor(_ trend: String) -> Color {
        switch trend.lowercased() {
        case "increasing":
            return .red
        case "decreasing":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Helper Views

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if width + size.width + spacing > maxWidth {
                width = 0
                height += lineHeight + spacing
                lineHeight = 0
            }
            width += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        height += lineHeight
        return CGSize(width: maxWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedSize, subviews: Subviews, cache _: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width + spacing > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    MainView(viewModel: MainViewModel())
}
