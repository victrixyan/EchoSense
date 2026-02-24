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
            
            VStack(spacing: isRecording ? 10 : 20) {
                // CONTINUOUS INFERENCE STATUS (No box, minimal)
                HStack(spacing: 8) {
                    Circle()
                        .fill(isRecording ? primaryGreen : primaryGreen.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .opacity(isRecording ? 0.8 : 1)
                        .scaleEffect(isRecording ? 1.2 : 1)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: isRecording), value: isRecording)
                    
                    Text(isRecording ? "Processing audio..." : "Ready for assessment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 0)
                
                // Header: Model Status Indicator (Hidden while recording)
                if !isRecording {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(viewModel.modelLoaded ? primaryGreen : Color.orange)
                            .frame(width: 12, height: 12)
                            .shadow(color: viewModel.modelLoaded ? primaryGreen.opacity(0.5) : Color.orange.opacity(0.5), radius: 4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("EchoSense")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            
                            Text(viewModel.modelLoaded ? "Ready" : "Loading model...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 24))
                            .foregroundColor(primaryGreen)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                
                // SECTION 1: Patient State - Horizontal Progress Bar
                VStack(alignment: .leading, spacing: isRecording ? 6 : 8) {
                    Text("Patient State")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    HStack(alignment: .center, spacing: isRecording ? 12 : 16) {
                        // Left: Horizontal Progress Bar
                        ZStack(alignment: .leading) {
                            // Background bar
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray4))
                            
                            // Progress fill with gradient
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: primaryGreen, location: 0.0),
                                            .init(color: Color.yellow, location: 0.5),
                                            .init(color: agitationRed, location: 1.0)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .scaleEffect(x: CGFloat(viewModel.agitation) / 10.0, anchor: .leading)
                                .animation(.easeInOut(duration: 8.0), value: viewModel.agitation)
                        }
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        
                        // Right: Score Circle
                        ZStack {
                            // Circle background
                            Circle()
                                .fill(agitationColor(viewModel.agitation).opacity(0.15))
                            
                            // Score text
                            VStack(spacing: 2) {
                                Text("\(viewModel.agitation)")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(agitationColor(viewModel.agitation))
                                    .animation(.easeInOut(duration: 0.1), value: viewModel.agitation)
                                Text("/ 10")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 60, height: 60)
                    }
                }
                .padding(isRecording ? 10 : 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(.systemGray6),
                            Color(.systemGray6).opacity(0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                // SECTION 2: Trend (One phrase, 60s, fade in/out)
                VStack(alignment: .leading, spacing: isRecording ? 3 : 6) {
                    Text("Trend")
                        .font(.system(.subheadline, design: .default))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.3)
                    
                    Text(viewModel.trend.capitalized)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(trendColor(viewModel.trend))
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .opacity(viewModel.trendFadeOut ? 0 : 1)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.trendFadeOut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(isRecording ? 8 : 12)
                .background(trendBgColor(viewModel.trend).opacity(0.1))
                .cornerRadius(16)
                .border(trendColor(viewModel.trend).opacity(0.2), width: 1)
                
                // SECTION 3: Keywords (Emotional triggers, context, topics. Max 2-3)
                if !viewModel.keywords.isEmpty {
                    VStack(alignment: .leading, spacing: isRecording ? 4 : 6) {
                        Text("Detected Topics")
                            .font(.system(.subheadline, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.3)
                        
                        FlowLayout(spacing: isRecording ? 4 : 8, horizontalSpacing: isRecording ? 4 : 8) {
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
                    .padding(isRecording ? 8 : 14)
                    .background(primaryGreen.opacity(0.05))
                    .cornerRadius(16)
                    .border(primaryGreen.opacity(0.2), width: 1)
                }
                
                // SECTION 5: Prediction Guidance (Concise format)
                if !viewModel.nudges.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Guidance")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: viewModel.agitation >= 9 ?
                                  "exclamationmark.triangle.fill" :
                                  viewModel.agitation >= 7 ?
                                  "heart.fill" :
                                  "sparkles")
                                .font(.system(size: 14))
                                .foregroundColor(viewModel.agitation >= 9 ? agitationRed : viewModel.agitation >= 7 ? Color.orange : primaryGreen)
                                .frame(width: 18)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                if viewModel.agitation >= 9 {
                                    Text("Priority: Safety First")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(agitationRed)
                                    Text("Assess immediate safety. Use calm presence. Contact care team.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                } else if viewModel.agitation >= 7 {
                                    Text("Approach: Validation")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.orange)
                                    Text("Acknowledge feelings. Offer reassurance. Avoid debate.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                } else {
                                    Text("Approach: Engagement")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(primaryGreen)
                                    Text("Explore interests. Share activities. Build connection.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(.systemGray5).opacity(0.5))
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(isRecording ? 10 : 12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(16)
                }
                
                Spacer(minLength: isRecording ? 6 : 10)
                
                // PATIENT CONTEXT INPUT (Hidden while recording to save space)
                if !isRecording {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Patient Context")
                            .font(.system(.subheadline, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.3)
                        
                        TextEditor(text: $userPrompt)
                            .frame(height: 70)
                            .padding(6)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryGreen.opacity(0.3), lineWidth: 1)
                            )
                            .font(.system(.body, design: .default))
                    }
                }
                
                // SECTION 4: Response Suggestions (Moved to bottom, above recording button)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Response Suggestions")
                        .font(.system(.subheadline, design: .default))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.3)
                    
                    if !viewModel.nudges.isEmpty {
                        VStack(alignment: .leading, spacing: isRecording ? 4 : 6) {
                            ForEach(viewModel.nudges, id: \.self) { nudge in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: viewModel.agitation >= 9 ?
                                          "exclamationmark.triangle.fill" :
                                          viewModel.agitation >= 7 ?
                                          "exclamationmark.circle.fill" :
                                          "lightbulb.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(viewModel.agitation >= 9 ? agitationRed : viewModel.agitation >= 7 ? .orange : accentTeal)
                                    
                                    Text(nudge)
                                        .font(.headline)
                                        .lineLimit(nil)
                                        .foregroundColor(.black)
                                    
                                    Spacer(minLength: 0)
                                }
                                .padding(8)
                                .background(
                                    viewModel.agitation >= 9 ?
                                    agitationRed.opacity(0.1) :
                                    viewModel.agitation >= 7 ?
                                    Color.orange.opacity(0.1) :
                                    accentTeal.opacity(0.1)
                                )
                                .cornerRadius(12)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                .animation(.easeInOut(duration: 0.5), value: nudge)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                    } else {
                        Text("Awaiting first assessment...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    viewModel.agitation >= 9 ?
                    agitationRed.opacity(0.05) :
                    viewModel.agitation >= 7 ?
                    Color.orange.opacity(0.05) :
                    accentTeal.opacity(0.05)
                )
                .cornerRadius(16)
                .border(
                    viewModel.agitation >= 9 ?
                    agitationRed.opacity(0.2) :
                    viewModel.agitation >= 7 ?
                    Color.orange.opacity(0.2) :
                    accentTeal.opacity(0.2),
                    width: 1
                )
                .opacity(viewModel.nudgeFadeOut ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: viewModel.nudgeFadeOut)
                
                // RECORDING CONTROL BUTTON
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
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
                            .font(.system(size: 26))
                        
                        Text(isRecording ? "Stop Recording" : "Start Recording")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
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
                            .font(.body)
                        
                        Text(error)
                            .font(.body)
                            .foregroundColor(.orange)
                            .lineLimit(3)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // INFERENCE STATUS
                if viewModel.isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.8, anchor: .center)
                        
                        Text("Analyzing audio...")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(primaryGreen.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
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
    
    // MARK: - Agitation Level
    
    private func agitationLevel(_ score: Int) -> String {
        switch score {
        case 0...2: return "Calm"
        case 3...4: return "Relaxed"
        case 5...6: return "Moderate"
        case 7...8: return "Elevated"
        case 9...10: return "Critical"
        default: return "Unknown"
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

struct PredictionExample: View {
    let icon: String
    let title: String
    let prompt: String
    let backgroundColor: Color
    let foregroundColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(foregroundColor)
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Text(prompt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding(10)
        .background(backgroundColor)
        .cornerRadius(12)
    }
}

struct KeywordPill: View {
    let text: String
    let backgroundColor: Color
    let foregroundColor: Color
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(12)
    }
}

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let horizontalSpacing: CGFloat
    let content: Content
    
    @State private var totalHeight = CGFloat.zero
    
    init(spacing: CGFloat = 8, horizontalSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.horizontalSpacing = horizontalSpacing
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: horizontalSpacing) {
            content
        }
    }
}

// Helper for creating FlowLayout with array of items
struct FlowLayoutArray<Item, Content: View>: View {
    let spacing: CGFloat
    let horizontalSpacing: CGFloat
    let items: [Item]
    let content: (Item) -> Content
    
    init(spacing: CGFloat = 8, horizontalSpacing: CGFloat = 8, items: [Item] = [], @ViewBuilder content: @escaping (Item) -> Content) {
        self.spacing = spacing
        self.horizontalSpacing = horizontalSpacing
        self.items = items
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                content(item)
                    .lineLimit(1)
            }
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

// MARK: - Custom Progress Bar Shape (Zero Layout Dependency)
struct AgitationBarShape: Shape {
    let progress: CGFloat  // 0.0 to 1.0
    let cornerRadius: CGFloat = 16
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Calculate fill width based on progress
        let fillWidth = rect.width * progress
        
        // Draw rounded rectangle for fill bar
        if fillWidth > 0 {
            let fillRect = CGRect(x: rect.minX, y: rect.minY, width: max(fillWidth, cornerRadius * 2), height: rect.height)
            path.addRoundedRect(in: fillRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
        
        return path
    }
}

#Preview {
    MainView(viewModel: MainViewModel())
}
