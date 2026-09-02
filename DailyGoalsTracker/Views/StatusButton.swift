import SwiftUI

/// Visual status toggle button with animated state transitions
struct StatusButton: View {
    let status: GoalStatus
    let size: CGFloat
    let action: () -> Void
    
    init(status: GoalStatus, size: CGFloat = 28, action: @escaping () -> Void) {
        self.status = status
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button {
            // Immediate action - no delay
            action()
        } label: {
            ZStack {
                // Background circle for better touch target
                Circle()
                    .fill(status.color.opacity(0.15))
                    .frame(width: size + 8, height: size + 8)
                
                // Status icon
                Image(systemName: status.iconName)
                    .font(.system(size: size * 0.75, weight: .medium))
                    .foregroundStyle(status.color)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(StatusButtonStyle())
        .accessibilityLabel(status.accessibilityLabel)
        .accessibilityHint("Tap to change status")
    }
}

/// Custom button style for instant feedback
struct StatusButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Compact status indicator (non-interactive)
struct StatusIndicator: View {
    let status: GoalStatus
    let size: CGFloat
    
    init(status: GoalStatus, size: CGFloat = 12) {
        self.status = status
        self.size = size
    }
    
    var body: some View {
        Image(systemName: status.iconName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(status.color)
    }
}

/// Mini status dot for calendar/grid views
struct StatusDot: View {
    let status: GoalStatus
    let size: CGFloat
    
    init(status: GoalStatus, size: CGFloat = 8) {
        self.status = status
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .overlay {
                if status == .partial {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: size / 2, height: size)
                        .offset(x: size / 4)
                        .clipShape(Circle())
                }
            }
    }
}

// MARK: - Preview
#Preview("Status Button") {
    HStack(spacing: 20) {
        StatusButton(status: .notDone) {}
        StatusButton(status: .partial) {}
        StatusButton(status: .done) {}
    }
    .padding()
}

#Preview("Status Indicators") {
    HStack(spacing: 12) {
        StatusIndicator(status: .notDone)
        StatusIndicator(status: .partial)
        StatusIndicator(status: .done)
    }
    .padding()
}

#Preview("Status Dots") {
    HStack(spacing: 8) {
        StatusDot(status: .notDone)
        StatusDot(status: .partial)
        StatusDot(status: .done)
    }
    .padding()
}
