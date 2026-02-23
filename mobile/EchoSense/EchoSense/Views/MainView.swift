//
//  MainView.swift
//  EchoSense
//
//  Created by Victrix Yan on 2026/2/23.
//

import SwiftUI
import AVFoundation

/// Minimalist PCDC-aligned UI following the EchoSense logo design language (green/teal palette).
/// Real-time response to dementia vocal inputs with smooth animations and non-intrusive feedback.
struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @State var userPrompt: String = ""
    @State var isRecording = false
    @State var recordingDuration: TimeInterval = 0
    @State var recordingTimer: Timer?
    
    // Theme colors matching EchoSense logo
    let primaryGreen = Color(red: 0.502, green: 0.686, blue: 0.439)    // #80AF70
    let accentTeal = Color(red: 0.388, green: 0.596, blue: 0.490)      // #6399 7D
    let calmnessBlue = Color(red: 0.224, green: 0.561, blue: 0.788)    // #398CC8
    let agitationRed = Color(red: 0.922, green: 0.408, blue: 0.318)    // #EB6851
    
    var body: some View {
        ZStack {
            // Background gradient (subtle)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white,
                    primaryGreen.opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header: Model Status Indicator
                HStack(spacing: 12) {
                    Circle()
                        .fill(viewModel.modelLoaded ? primaryGreen : Color.orange)
                        .frame(width: 12, height: 12)
                        .shadow(color: viewModel.modelLoaded ? primaryGreen.opacity(0.5) : Color.orange.opacity(0.5), radius: 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EchoSense")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Text(viewModel.modelLoaded ? "Ready" : "Loading model...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 24))
                        .foregroundColor(primaryGreen)
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // SECTION 1: Agitation Bar (Dynamic, Color-coded, 10s smooth)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Patient State")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                        Spacer()
                        Text("\(viewModel.agitation)/10")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(agitationColor(viewModel.agitation))
                            .animation(.easeInOut(duration: 0.1), value: viewModel.agitation)
                    }
                    
                    // Agitation Bar with Smooth Lerp
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray4))
                            .frame(height: 24)
                        
                        // Gradient fill (calm blue → agitation red)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        calmnessBlue,
                                        primaryGreen,
                                        Color.orange,
                                        agitationRed
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(24, 280 * CGFloat(viewModel.agitation) / 10.0), height: 24)
                            .animation(.easeInOut(duration: 10.0), value: viewModel.agitation)
                        
                        // Label: Calm ... Agitation
                        HStack(spacing: 0) {
                            Text("Calm")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .opacity(0.7)
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            Text("Agitation")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .opacity(0.7)
                                .padding(.trailing, 8)
                        }
                    }
                    .frame(height: 24)
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // SECTION 2: Trend (One phrase, 60s, fade in/out)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trend")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text(viewModel.trend.capitalized)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(trendColor(viewModel.trend))
                        .lineLimit(2)
                        .opacity(viewModel.trendFadeOut ? 0 : 1)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.trendFadeOut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(trendBgColor(viewModel.trend).opacity(0.1))
                .cornerRadius(12)
                .border(trendColor(viewModel.trend).opacity(0.2), width: 1)
                
                // SECTION 3: Keywords (Emotional triggers, context, topics. Max 2-3)
                if !viewModel.keywords.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Detected Topics")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        FlowLayout(spacing: 8, horizontalSpacing: 8) {
                            ForEach(viewModel.keywords, id: \.self) { keyword in
                                KeywordPill(
                                    text: keyword,
                                    backgroundColor: primaryGreen.opacity(0.15),
                                    foregroundColor: primaryGreen
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(primaryGreen.opacity(0.05))
                    .cornerRadius(12)
                    .border(primaryGreen.opacity(0.2), width: 1)
                }
                
                // SECTION 4: Response Prompts (Rolling, 15-20s, fade in/out, escalation override)
                if !viewModel.nudges.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Response Suggestions")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.nudges, id: \.self) { nudge in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: viewModel.agitation >= 7 ?
                                          "exclamationmark.circle.fill" :
                                          "lightbulb.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(viewModel.agitation >= 7 ? .orange : accentTeal)
                                    
                                    Text(nudge)
                                        .font(.callout)
                                        .lineLimit(3)
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                }
                                .padding(10)
                                .background(
                                    viewModel.agitation >= 7 ?
                                    Color.orange.opacity(0.1) :
                                    accentTeal.opacity(0.1)
                                )
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        viewModel.agitation >= 7 ?
                        Color.orange.opacity(0.05) :
                        accentTeal.opacity(0.05)
                    )
                    .cornerRadius(12)
                    .border(
                        viewModel.agitation >= 7 ?
                        Color.orange.opacity(0.2) :
                        accentTeal.opacity(0.2),
                        width: 1
                    )
                    .opacity(viewModel.nudgeFadeOut ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.nudgeFadeOut)
                }
                
                Spacer()
                
                // PATIENT CONTEXT INPUT
                VStack(alignment: .leading, spacing: 8) {
                    Text("Patient Context")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    TextEditor(text: $userPrompt)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(primaryGreen.opacity(0.3), lineWidth: 1)
                        )
                        .font(.system(.body, design: .default))
                }
                
                // RECORDING CONTROL BUTTON
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    primaryGreen,
                                    accentTeal
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: primaryGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    HStack(spacing: 12) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 22))
                        
                        Text(isRecording ? "Stop Recording" : "Start Recording")
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if isRecording {
                            Text(String(format: "%.0f s", recordingDuration))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(16)
                }
                .frame(height: 54)
                .onTapGesture {
                    toggleRecording()
                }
                .disabled(!viewModel.modelLoaded)
                .opacity(viewModel.modelLoaded ? 1 : 0.6)
                
                // ERROR MESSAGE
                if let error = viewModel.errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .lineLimit(3)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // INFERENCE STATUS
                if viewModel.isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.8, anchor: .center)
                        
                        Text("Analyzing audio...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(primaryGreen.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(16)
        }
        .navigationTitle("EchoSense")
        .onAppear {
            requestMicrophonePermission()
        }
        .onDisappear {
            stopAllTimers()
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingDuration = 0
        viewModel.startRecording(withContext: userPrompt)
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func stopRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        viewModel.stopRecording()
    }
    
    private func stopAllTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func requestMicrophonePermission() {
        viewModel.speechManager.requestMicrophonePermission { granted in
            if !granted {
                viewModel.errorMessage = "Microphone access required for audio recording"
            }
        }
    }
    
    // MARK: - Color Functions
    
    private func agitationColor(_ score: Int) -> Color {
        if score <= 2 {
            return calmnessBlue
        } else if score <= 4 {
            return calmnessBlue.opacity(0.7).mix(with: primaryGreen, by: 0.3)
        } else if score <= 6 {
            return primaryGreen
        } else if score <= 8 {
            return primaryGreen.mix(with: Color.orange, by: 0.5)
        } else {
            return agitationRed
        }
    }
    
    private func trendColor(_ trend: String) -> Color {
        switch trend.lowercased() {
        case let t where t.contains("increasing") || t.contains("escalat"):
            return agitationRed
        case let t where t.contains("decreasing") || t.contains("calm"):
            return primaryGreen
        default:
            return accentTeal
        }
    }
    
    private func trendBgColor(_ trend: String) -> Color {
        switch trend.lowercased() {
        case let t where t.contains("increasing") || t.contains("escalat"):
            return agitationRed
        case let t where t.contains("decreasing") || t.contains("calm"):
            return primaryGreen
        default:
            return accentTeal
        }
    }
}

// MARK: - Helper Components

struct KeywordPill: View {
    let text: String
    let backgroundColor: Color
    let foregroundColor: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(6)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    let horizontalSpacing: CGFloat
    
    func sizeThatFits(
        proposal: ProposedSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if width + size.width + horizontalSpacing > maxWidth {
                width = 0
                height += lineHeight + spacing
                lineHeight = 0
            }
            width += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
        
        height += lineHeight
        return CGSize(width: maxWidth, height: height)
    }
    
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width + horizontalSpacing > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedSize(size))
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

extension Color {
    func mix(with other: Color, by amount: CGFloat) -> Color {
        let amount = max(0, min(1, amount))
        let colorA = UIColor(self)
        let colorB = UIColor(other)
        
        var redA: CGFloat = 0, greenA: CGFloat = 0, blueA: CGFloat = 0, alphaA: CGFloat = 0
        colorA.getRed(&redA, green: &greenA, blue: &blueA, alpha: &alphaA)
        
        var redB: CGFloat = 0, greenB: CGFloat = 0, blueB: CGFloat = 0, alphaB: CGFloat = 0
        colorB.getRed(&redB, green: &greenB, blue: &blueB, alpha: &alphaB)
        
        let mixed = UIColor(
            red: redA + (redB - redA) * amount,
            green: greenA + (greenB - greenA) * amount,
            blue: blueA + (blueB - blueA) * amount,
            alpha: alphaA + (alphaB - alphaA) * amount
        )
        
        return Color(mixed)
    }
}

#Preview {
    MainView(viewModel: MainViewModel())
}
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
