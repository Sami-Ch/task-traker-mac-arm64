import SwiftUI

/// Labeled chevron back control. Padding and a rectangular content shape make the
/// space between and around the icon and title part of the click target.
struct BackLinkButton: View {
    let title: String
    var helpText: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.body)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.vertical, 10)
            .padding(.trailing, 16)
            .padding(.leading, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText ?? "Back to \(title)")
    }
}

/// Fixed-height navigation header used across Day / Week / Month views.
/// Height is shared by every tab so switching tabs never moves the content below it.
struct PeriodNavigationHeader: View {
    let title: String
    let subtitle: String?
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    static let height: CGFloat = 40
    
    var body: some View {
        HStack(spacing: 8) {
            navButton(systemName: "chevron.left", action: onPrevious)
            
            VStack(spacing: 0) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            
            navButton(systemName: "chevron.right", action: onNext)
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
    }
    
    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
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
    
    static let height: CGFloat = 32
    
    var body: some View {
        HStack(spacing: 8) {
            MiniProgressRing(progress: progress, size: 16)
            
            Text("\(Int(progress * 100))%")
                .font(.subheadline.weight(.semibold).monospacedDigit())
            
            Image(systemName: trailingIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(trailingText)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: Self.height)
    }
}
