import SwiftUI

/// Weekly goals view — label column expands to fill the wider popover.
struct WeekView: View {
    @Environment(DataStore.self) private var dataStore
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    private let dayColumnWidth: CGFloat = 32
    private let rowHeight: CGFloat = 28
    private let headerRowHeight: CGFloat = 28
    private let horizontalPadding: CGFloat = 12
    
    private var weekStart: Date {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
    }
    
    private var weekDates: [Date] {
        (0..<7).map { calendar.date(byAdding: .day, value: $0, to: weekStart)! }
    }
    
    private var weekProgress: Double {
        let summaries = weekDates.map { dataStore.getDailySummary(for: $0) }
        return summaries.reduce(0.0) { $0 + $1.completionPercentage } / 7.0
    }
    
    private var activeGoals: [Goal] {
        dataStore.goals.filter(\.isActive)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PeriodNavigationHeader(
                title: weekTitle,
                subtitle: weekSubtitle,
                onPrevious: {
                    selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                },
                onNext: {
                    selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                }
            )
            
            Divider().padding(.horizontal)
            
            SummaryStrip(
                progress: weekProgress,
                trailingIcon: "star.fill",
                trailingText: "\(perfectDays) perfect"
            )
            
            compactDayHeaders
            
            goalRows
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var goalRows: some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                if activeGoals.isEmpty {
                    Text("No active goals")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, horizontalPadding)
                        .frame(height: rowHeight)
                } else {
                    ForEach(activeGoals) { goal in
                        weekGoalRow(for: goal)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.top)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var weekTitle: String {
        let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        if calendar.isDate(weekStart, equalTo: thisWeekStart, toGranularity: .weekOfYear) {
            return "This Week"
        } else if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart),
                  calendar.isDate(weekStart, equalTo: lastWeek, toGranularity: .weekOfYear) {
            return "Last Week"
        } else if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeekStart),
                  calendar.isDate(weekStart, equalTo: nextWeek, toGranularity: .weekOfYear) {
            return "Next Week"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "'Week' w"
            return formatter.string(from: weekStart)
        }
    }
    
    private var weekSubtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekDates.last!))"
    }
    
    private var perfectDays: Int {
        weekDates.filter { dataStore.getDailySummary(for: $0).completionPercentage >= 1.0 }.count
    }
    
    private var compactDayHeaders: some View {
        HStack(spacing: 0) {
            Text("Goal")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(weekDates, id: \.self) { date in
                let isToday = calendar.isDateInToday(date)
                VStack(spacing: 1) {
                    Text(dayName(for: date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isToday ? AnyShapeStyle(.blue) : AnyShapeStyle(.tertiary))
                    Text(dayNumber(for: date))
                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? AnyShapeStyle(.blue) : AnyShapeStyle(.primary))
                }
                .frame(width: dayColumnWidth, height: headerRowHeight)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
    
    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
    
    private func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func weekGoalRow(for goal: Goal) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                GoalIconView(icon: goal.icon, size: 11)
                Text(goal.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(goal.title)
            
            ForEach(weekDates, id: \.self) { date in
                let tracked = dataStore.isGoalTracked(goal, on: date)
                let entry = dataStore.getEntry(for: goal.id, on: date)
                
                if tracked {
                    Button {
                        dataStore.cycleStatus(for: goal.id, on: date)
                    } label: {
                        StatusDot(status: entry.status, size: 14)
                            .frame(width: dayColumnWidth, height: rowHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("–")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: dayColumnWidth, height: rowHeight)
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: rowHeight)
    }
}

#Preview("Week View") {
    WeekView(selectedDate: .constant(Date()))
        .environment(DataStore())
        .frame(width: 400, height: 600)
}
