import SwiftUI

/// Daily goals view with progress ring and goal list
struct DayView: View {
    @Environment(DataStore.self) private var dataStore
    @Binding var selectedDate: Date
    
    private var summary: DailySummary {
        dataStore.getDailySummary(for: selectedDate)
    }
    
    private var dayGoals: (tracked: [Goal], skipped: [Goal]) {
        dataStore.goalsForDay(selectedDate)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PeriodNavigationHeader(
                title: dateTitle,
                subtitle: isToday ? nil : fullDate,
                onPrevious: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                },
                onNext: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            )
            
            Divider().padding(.horizontal)
            
            DayModePicker(date: selectedDate)
            
            Divider().padding(.horizontal)
            
            HStack(spacing: 8) {
                MiniProgressRing(progress: summary.completionPercentage, size: 14)
                Text("\(Int(summary.completionPercentage * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                if summary.isSpecialDay {
                    Image(systemName: summary.dayMode.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(summary.dayMode.color)
                }
                HStack(spacing: 8) {
                    compactStat(count: summary.doneCount, color: .green)
                    compactStat(count: summary.partialCount, color: .orange)
                    compactStat(count: summary.notDoneCount, color: .gray)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: SummaryStrip.height)
            
            goalRows
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var goalRows: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(dayGoals.tracked) { goal in
                    let entry = dataStore.getEntry(for: goal.id, on: selectedDate)
                    GoalRow(goal: goal, entry: entry, showsEssentialBadge: goal.isEssential) {
                        dataStore.cycleStatus(for: goal.id, on: selectedDate)
                    }
                }
                
                SkippedGoalsSection(goals: dayGoals.skipped)
            }
            .padding(.top, 4)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.top)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private func compactStat(count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
    }
    
    private var dateTitle: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }
    
    private var fullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }
}

#Preview("Day View") {
    DayView(selectedDate: .constant(Date()))
        .environment(DataStore())
        .frame(width: 340, height: 480)
}
