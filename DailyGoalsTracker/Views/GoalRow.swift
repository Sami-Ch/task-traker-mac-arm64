import SwiftUI

/// Single goal row with icon, title, and status toggle
struct GoalRow: View {
    let goal: Goal
    let entry: GoalEntry
    var showsEssentialBadge: Bool = false
    let onStatusChange: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            GoalIconView(icon: goal.icon, size: 14)
            
            HStack(spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                if showsEssentialBadge {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                }
            }
            
            Spacer()
            
            StatusButton(status: entry.status, size: 24, action: onStatusChange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(height: 36)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

/// Compact goal row for week view
struct CompactGoalRow: View {
    let goal: Goal
    let entries: [GoalEntry]  // 7 days
    let onStatusChange: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Goal icon & title
            HStack(spacing: 6) {
                GoalIconView(icon: goal.icon, size: 10)
                
                Text(goal.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)
            
            // Week status dots
            HStack(spacing: 4) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    Button {
                        onStatusChange(index)
                    } label: {
                        StatusDot(status: entry.status, size: 16)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview("Goal Row") {
    VStack(spacing: 0) {
        GoalRow(
            goal: Goal(title: "Exercise", icon: "figure.run"),
            entry: GoalEntry(goalId: UUID(), date: Date(), status: .done),
            onStatusChange: {}
        )
        GoalRow(
            goal: Goal(title: "Read for 30 minutes", icon: "book.fill"),
            entry: GoalEntry(goalId: UUID(), date: Date(), status: .partial),
            onStatusChange: {}
        )
        GoalRow(
            goal: Goal(title: "Meditate", icon: "brain.head.profile"),
            entry: GoalEntry(goalId: UUID(), date: Date(), status: .notDone),
            onStatusChange: {}
        )
    }
    .frame(width: 300)
    .padding()
}
