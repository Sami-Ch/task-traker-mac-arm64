import SwiftUI

/// Monthly calendar view with heat-map visualization
struct MonthView: View {
    @Environment(DataStore.self) private var dataStore
    @Binding var selectedDate: Date
    var onDayTap: ((Date) -> Void)?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    private var presentation: CalendarPresentation {
        dataStore.calendarPresentation
    }
    
    private var daysInMonth: [Date?] {
        presentation.monthGridDays(containing: selectedDate)
    }
    
    private var monthSummaries: [Date: DailySummary] {
        dataStore.getMonthEntries(for: selectedDate)
    }
    
    private var monthProgress: Double {
        let summaries = Array(monthSummaries.values)
        guard !summaries.isEmpty else { return 0 }
        let total = summaries.reduce(0.0) { $0 + $1.completionPercentage }
        return total / Double(summaries.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PeriodNavigationHeader(
                title: presentation.monthTitle(for: selectedDate),
                subtitle: nil,
                onPrevious: {
                    selectedDate = presentation.shiftedMonth(selectedDate, by: -1)
                },
                onNext: {
                    selectedDate = presentation.shiftedMonth(selectedDate, by: 1)
                }
            )
            
            Divider().padding(.horizontal)
            
            SummaryStrip(
                progress: monthProgress,
                trailingIcon: "star.fill",
                trailingText: "\(perfectDaysCount) perfect"
            )
            
            weekdayHeaders
            
            Divider().padding(.horizontal, 8)
            
            calendarGrid
                .padding(.horizontal, 8)
                .padding(.top, 4)
            
            legend
                .padding(.vertical, 6)
            
            Spacer(minLength: 0)
        }
    }
    
    private var perfectDaysCount: Int {
        monthSummaries.values.filter { $0.completionPercentage >= 1.0 }.count
    }
    
    private var weekdayHeaders: some View {
        HStack(spacing: 4) {
            ForEach(Array(presentation.weekDates(containing: selectedDate).enumerated()), id: \.offset) { _, date in
                let jumuah = presentation.isJumuah(date)
                Text(presentation.weekdayHeaderLetter(for: date))
                    .font(.system(size: 9, weight: jumuah ? .semibold : .medium))
                    .foregroundStyle(jumuah && dataStore.settings.calendarDisplay.usesIslamicWeek ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                    .frame(maxWidth: .infinity)
                    .help(presentation.weekdayName(for: date, style: .full))
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }
    
    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    let civil = GoalEntry.startOfCivilDay(for: date)
                    CalendarDayCell(
                        date: date,
                        dayLabel: presentation.dayNumber(for: date),
                        secondaryLabel: presentation.secondaryDayNumber(for: date),
                        summary: monthSummaries[civil],
                        isToday: dataStore.isLogicalToday(date),
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        isJumuah: presentation.isJumuah(date) && dataStore.settings.calendarDisplay.usesIslamicWeek,
                        hasJournal: dataStore.hasJournal(on: date)
                    ) {
                        onDayTap?(date)
                    }
                } else {
                    Color.clear
                        .frame(height: 36)
                }
            }
        }
    }
    
    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .gray.opacity(0.2), label: "0%")
            legendItem(color: .green.opacity(0.3), label: "25%")
            legendItem(color: .green.opacity(0.5), label: "50%")
            legendItem(color: .green.opacity(0.7), label: "75%")
            legendItem(color: .green, label: "100%")
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
        }
    }
}

// MARK: - Calendar Day Cell
private struct CalendarDayCell: View {
    let date: Date
    let dayLabel: String
    var secondaryLabel: String? = nil
    let summary: DailySummary?
    let isToday: Bool
    let isSelected: Bool
    var isJumuah: Bool = false
    var hasJournal: Bool = false
    let action: () -> Void
    
    private var progress: Double {
        summary?.completionPercentage ?? 0
    }
    
    private var backgroundColor: Color {
        if summary?.isSpecialDay == true {
            let mode = summary?.dayMode ?? DayMode.normalFallback
            return mode.color.opacity(0.15 + progress * 0.35)
        }
        if progress == 0 {
            return .gray.opacity(0.1)
        } else if progress < 0.5 {
            return .green.opacity(0.2 + progress * 0.3)
        } else {
            return .green.opacity(0.35 + progress * 0.4)
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
                
                VStack(spacing: 0) {
                    Text(dayLabel)
                        .font(.system(size: 12, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .blue : (isJumuah ? .green : .primary))
                    if let secondaryLabel {
                        Text(secondaryLabel)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if summary?.isSpecialDay == true {
                    Image(systemName: summary?.dayMode.icon ?? "leaf.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(summary?.dayMode.color ?? .green)
                        .padding(3)
                }
                
                if hasJournal {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 4, height: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 3)
                }
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.blue, lineWidth: 2)
                }
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
        .help(dayHelp)
    }
    
    private var dayHelp: String {
        GoalEntry.dateString(from: date)
    }
}

#Preview("Month View") {
    MonthView(selectedDate: .constant(Date()))
        .environment(DataStore())
        .frame(width: 400, height: 600)
}
