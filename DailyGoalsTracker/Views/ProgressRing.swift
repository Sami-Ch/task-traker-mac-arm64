import SwiftUI

/// Circular progress ring showing completion percentage
struct ProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let showPercentage: Bool
    
    @State private var animatedProgress: Double = 0
    
    init(progress: Double, size: CGFloat = 60, lineWidth: CGFloat = 6, showPercentage: Bool = true) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.showPercentage = showPercentage
    }
    
    private var progressColor: Color {
        switch progress {
        case 0..<0.25: return .red
        case 0.25..<0.5: return .orange
        case 0.5..<0.75: return .yellow
        case 0.75..<1.0: return .green.opacity(0.8)
        default: return .green
        }
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    lineWidth: lineWidth
                )
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)
            
            // Percentage text
            if showPercentage {
                VStack(spacing: 0) {
                    Text("\(Int(animatedProgress * 100))")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: size * 0.14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

/// Mini progress ring for compact displays
struct MiniProgressRing: View {
    let progress: Double
    let size: CGFloat
    
    init(progress: Double, size: CGFloat = 20) {
        self.progress = progress
        self.size = size
    }
    
    private var progressColor: Color {
        switch progress {
        case 0..<0.5: return .orange
        case 0.5..<1.0: return .green.opacity(0.8)
        default: return .green
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview
#Preview("Progress Ring") {
    HStack(spacing: 20) {
        ProgressRing(progress: 0)
        ProgressRing(progress: 0.33)
        ProgressRing(progress: 0.66)
        ProgressRing(progress: 1.0)
    }
    .padding()
}

#Preview("Mini Progress Rings") {
    HStack(spacing: 12) {
        MiniProgressRing(progress: 0.25)
        MiniProgressRing(progress: 0.5)
        MiniProgressRing(progress: 0.75)
        MiniProgressRing(progress: 1.0)
    }
    .padding()
}
