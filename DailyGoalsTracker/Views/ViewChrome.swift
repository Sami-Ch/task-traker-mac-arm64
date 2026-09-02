import SwiftUI

/// Fixed-height navigation header used across Day / Week / Month views.
/// Height is shared by every tab so switching tabs never moves the content below it.
struct PeriodNavigationHeader: View {
    let title: String
    let subtitle: String?
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    static let height: CGFloat = 36
    
    var body: some View {
        HStack(spacing: 8) {
            navButton(systemName: "chevron.left", action: onPrevious)
            
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            
            navButton(systemName: "chevron.right", action: onNext)
        }
        .padding(.horizontal, 8)
        .frame(height: Self.height)
    }
    
    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Slim single-line summary strip. Fixed height keeps all tabs vertically aligned.
struct SummaryStrip: View {
    let progress: Double
    let trailingIcon: String
    let trailingText: String
    
    static let height: CGFloat = 26
    
    var body: some View {
        HStack(spacing: 8) {
            MiniProgressRing(progress: progress, size: 14)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            
            Image(systemName: trailingIcon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            
            Text(trailingText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: Self.height)
    }
}
