import SwiftUI

/// Compact picker to mark today as fasting, trip, rest, etc.
struct DayModePicker: View {
    @Environment(DataStore.self) private var dataStore
    let date: Date
    
    private var currentMode: DayMode {
        dataStore.getDayRecord(for: date).mode
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DayMode.allCases) { mode in
                        modeChip(mode)
                    }
                }
                .padding(.horizontal, 12)
            }
            
            if currentMode.tracksEssentialOnly {
                specialDayBanner
            }
        }
        .padding(.vertical, 6)
    }
    
    private func modeChip(_ mode: DayMode) -> some View {
        let selected = currentMode == mode
        
        return Button {
            dataStore.setDayMode(mode, for: date)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 9))
                Text(mode.shortTitle)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? .white : mode.color)
            .background {
                Capsule()
                    .fill(selected ? mode.color : mode.color.opacity(0.12))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var specialDayBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 9))
                .foregroundStyle(.yellow)
            Text("Only essential goals count today")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if dataStore.goalsForDay(date).skipped.count > 0 {
                Text("\(dataStore.goalsForDay(date).skipped.count) skipped")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
    }
}

/// Collapsed list of goals skipped on a special day.
struct SkippedGoalsSection: View {
    let goals: [Goal]
    @State private var isExpanded = false
    
    var body: some View {
        if !goals.isEmpty {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text("\(goals.count) goals skipped today")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    VStack(spacing: 2) {
                        ForEach(goals) { goal in
                            HStack(spacing: 8) {
                                GoalIconView(icon: goal.icon, size: 10, isActive: false)
                                Text(goal.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .strikethrough(true, color: Color.secondary.opacity(0.5))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            .background(Color.gray.opacity(0.06))
        }
    }
}
