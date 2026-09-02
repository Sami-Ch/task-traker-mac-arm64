import SwiftUI

/// Monthly calendar view with heat-map visualization
struct MonthView: View {
    @Environment(DataStore.self) private var dataStore
    @Binding var selectedDate: Date
    var onDayTap: ((Date) -> Void)?
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
    }
    
    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        
        // Adjust for week starting on Monday (weekday 2)
        let leadingEmptyDays = (firstWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        
        // Pad to complete last week
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
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
                title: monthTitle,
                subtitle: nil,
                onPrevious: {
                    selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                },
                onNext: {
                    selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
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
    
    // MARK: - Month Header (removed - using PeriodNavigationHeader)
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var perfectDaysCount: Int {
        monthSummaries.values.filter { $0.completionPercentage >= 1.0 }.count
    }
    
    // MARK: - Weekday Headers
    private var weekdayHeaders: some View {
        HStack(spacing: 4) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    CalendarDayCell(
                        date: date,
                        summary: monthSummaries[date],
                        isToday: calendar.isDateInToday(date),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                    ) {
                        onDayTap?(date)
                    }
                } else {
                    Color.clear
                        .frame(height: 32)
                }
            }
        }
    }
    
    // MARK: - Legend
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
    let summary: DailySummary?
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void
    
    private var progress: Double {
        summary?.completionPercentage ?? 0
    }
    
    private var backgroundColor: Color {
        if summary?.isSpecialDay == true {
            let mode = summary?.dayMode ?? .normal
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
                
                Text(dayNumber)
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .blue : .primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if summary?.isSpecialDay == true {
                    Image(systemName: summary?.dayMode.icon ?? "leaf.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(summary?.dayMode.color ?? .green)
                        .padding(3)
                }
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.blue, lineWidth: 2)
                }
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview("Month View") {
    MonthView(selectedDate: .constant(Date()))
        .environment(DataStore())
        .frame(width: 340, height: 520)
}
