import SwiftUI

/// Weekly goals view — label column expands to fill the wider popover.
struct WeekView: View {
    @Environment(DataStore.self) private var dataStore
    @Binding var selectedDate: Date
    
    private let dayColumnWidth: CGFloat = 32
    private let rowHeight: CGFloat = 28
    private let headerRowHeight: CGFloat = 28
    private let horizontalPadding: CGFloat = 12
    
    private var presentation: CalendarPresentation {
        dataStore.calendarPresentation
    }
    
    private var weekStart: Date {
        presentation.weekStart(containing: selectedDate)
    }
    
    private var weekDates: [Date] {
        presentation.weekDates(containing: selectedDate)
    }
    
    private var weekProgress: Double {
        let summaries = weekDates.map { dataStore.getDailySummary(for: $0) }
        return summaries.reduce(0.0) { $0 + $1.completionPercentage } / 7.0
    }
    
    private var weekGoals: [Goal] {
        dataStore.goalsForWeek(weekDates)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PeriodNavigationHeader(
                title: presentation.weekTitle(for: weekStart, logicalToday: dataStore.logicalDate()),
                subtitle: presentation.weekRangeSubtitle(weekStart: weekStart),
                onPrevious: {
                    selectedDate = presentation.shiftedWeek(selectedDate, by: -1)
                },
                onNext: {
                    selectedDate = presentation.shiftedWeek(selectedDate, by: 1)
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
                if weekGoals.isEmpty {
                    Text("No goals this week")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, horizontalPadding)
                        .frame(height: rowHeight)
                } else {
                    ForEach(weekGoals) { goal in
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
                let isToday = dataStore.isLogicalToday(date)
                let jumuah = presentation.isJumuah(date)
                VStack(spacing: 1) {
                    Text(presentation.weekdayHeaderLetter(for: date))
                        .font(.system(size: 10, weight: jumuah ? .semibold : .medium))
                        .foregroundStyle(isToday ? AnyShapeStyle(.blue) : jumuah ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                    Text(presentation.dayNumber(for: date))
                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? AnyShapeStyle(.blue) : AnyShapeStyle(.primary))
                }
                .frame(width: dayColumnWidth, height: headerRowHeight)
                .help(presentation.weekdayName(for: date, style: .full))
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 2)
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
