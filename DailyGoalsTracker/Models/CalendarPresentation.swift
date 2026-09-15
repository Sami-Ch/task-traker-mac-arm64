import Foundation

/// Formats day / week / month chrome for Gregorian, Hijri, or dual display.
/// Persistence keys stay Gregorian `yyyy-MM-dd`; this type is display-only.
struct CalendarPresentation {
    var mode: CalendarDisplayMode
    
    /// Layout calendar for week grids (civil dates, Monday- or Saturday-first).
    var layoutCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        calendar.firstWeekday = mode.usesIslamicWeek ? 7 : 2
        return calendar
    }
    
    var hijriCalendar: Calendar {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = TimeZone.current
        calendar.firstWeekday = 7
        return calendar
    }
    
    var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        calendar.firstWeekday = 2
        return calendar
    }
    
    var weekdayOrder: [WeekdaySet] {
        mode.usesIslamicWeek ? WeekdaySet.saturdayFirst : WeekdaySet.mondayFirst
    }
    
    func isJumuah(_ date: Date) -> Bool {
        gregorianCalendar.component(.weekday, from: date) == 6
    }
    
    func weekStart(containing date: Date) -> Date {
        let cal = layoutCalendar
        let start = GoalEntry.startOfCivilDay(for: date)
        let weekday = cal.component(.weekday, from: start)
        let offset = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -offset, to: start).map(GoalEntry.startOfCivilDay) ?? start
    }
    
    func weekDates(containing date: Date) -> [Date] {
        let start = weekStart(containing: date)
        return (0..<7).compactMap { offset in
            layoutCalendar.date(byAdding: .day, value: offset, to: start).map(GoalEntry.startOfCivilDay)
        }
    }
    
    func weekdayName(for date: Date, style: WeekdayNameStyle = .full) -> String {
        let weekday = WeekdaySet.forDate(date, calendar: gregorianCalendar)
        if mode == .gregorian {
            return gregorianWeekdayName(weekday, style: style)
        }
        return islamicWeekdayName(weekday, style: style)
    }
    
    func weekdayName(_ weekday: WeekdaySet, style: WeekdayNameStyle = .chip) -> String {
        if mode == .gregorian {
            return gregorianWeekdayName(weekday, style: style)
        }
        return islamicWeekdayName(weekday, style: style)
    }
    
    func islamicArabicName(_ weekday: WeekdaySet) -> String {
        switch weekday {
        case .sunday: return "الأحد"
        case .monday: return "الاثنين"
        case .tuesday: return "الثلاثاء"
        case .wednesday: return "الأربعاء"
        case .thursday: return "الخميس"
        case .friday: return "الجمعة"
        case .saturday: return "السبت"
        default: return ""
        }
    }
    
    func relativeTitle(for date: Date, logicalToday: Date) -> String {
        let cal = gregorianCalendar
        if cal.isDate(date, inSameDayAs: logicalToday) { return "Today" }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: logicalToday),
           cal.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: logicalToday),
           cal.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return weekdayName(for: date, style: .full)
    }
    
    func dateSubtitle(for date: Date) -> String {
        switch mode {
        case .gregorian:
            return gregorianLong.string(from: date)
        case .hijri:
            return hijriLong.string(from: date)
        case .dual:
            return "\(gregorianLong.string(from: date)) · \(hijriLong.string(from: date))"
        }
    }
    
    func monthTitle(for date: Date) -> String {
        switch mode {
        case .gregorian:
            return gregorianMonthYear.string(from: date)
        case .hijri:
            return hijriMonthYear.string(from: date)
        case .dual:
            let hijriSpan = hijriMonthSpan(inGregorianMonthOf: date)
            return "\(gregorianMonthYear.string(from: date)) · \(hijriSpan)"
        }
    }
    
    func weekTitle(for weekStart: Date, logicalToday: Date) -> String {
        let thisWeek = self.weekStart(containing: logicalToday)
        let cal = layoutCalendar
        if cal.isDate(weekStart, equalTo: thisWeek, toGranularity: .weekOfYear) {
            return "This Week"
        }
        if let last = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek),
           cal.isDate(weekStart, equalTo: last, toGranularity: .weekOfYear) {
            return "Last Week"
        }
        if let next = cal.date(byAdding: .weekOfYear, value: 1, to: thisWeek),
           cal.isDate(weekStart, equalTo: next, toGranularity: .weekOfYear) {
            return "Next Week"
        }
        return weekRangeSubtitle(weekStart: weekStart)
    }
    
    func weekRangeSubtitle(weekStart: Date) -> String {
        let dates = weekDates(containing: weekStart)
        guard let last = dates.last else { return "" }
        switch mode {
        case .gregorian:
            return "\(gregorianShort.string(from: weekStart)) – \(gregorianShort.string(from: last))"
        case .hijri:
            return "\(hijriShort.string(from: weekStart)) – \(hijriShort.string(from: last))"
        case .dual:
            return "\(gregorianShort.string(from: weekStart)) – \(gregorianShort.string(from: last))"
        }
    }
    
    func dayNumber(for date: Date) -> String {
        switch mode {
        case .gregorian, .dual:
            return gregorianDay.string(from: date)
        case .hijri:
            return hijriDay.string(from: date)
        }
    }
    
    func secondaryDayNumber(for date: Date) -> String? {
        guard mode == .dual else { return nil }
        return hijriDay.string(from: date)
    }
    
    func weekdayHeaderLetter(for date: Date) -> String {
        weekdayName(for: date, style: .letter)
    }
    
    func shiftedMonth(_ date: Date, by value: Int) -> Date {
        let calendar = mode == .hijri ? hijriCalendar : gregorianCalendar
        return calendar.date(byAdding: .month, value: value, to: date) ?? date
    }
    
    func shiftedWeek(_ date: Date, by value: Int) -> Date {
        layoutCalendar.date(byAdding: .weekOfYear, value: value, to: date) ?? date
    }
    
    func shiftedDay(_ date: Date, by value: Int) -> Date {
        gregorianCalendar.date(byAdding: .day, value: value, to: gregorianCalendar.startOfDay(for: date)) ?? date
    }
    
    /// Days in the displayed month, padded to full weeks. Dual and Gregorian use the civil month.
    func monthGridDays(containing date: Date) -> [Date?] {
        if mode == .hijri {
            return paddedMonthDays(calendar: hijriCalendar, containing: date)
        }
        return paddedMonthDays(calendar: gregorianCalendar, containing: date)
    }
    
    func monthDayDates(containing date: Date) -> [Date] {
        monthGridDays(containing: date).compactMap { $0 }
    }
    
    // MARK: - Names
    
    enum WeekdayNameStyle {
        case full, chip, letter
    }
    
    private func gregorianWeekdayName(_ weekday: WeekdaySet, style: WeekdayNameStyle) -> String {
        switch (weekday, style) {
        case (.monday, .full): return "Monday"
        case (.tuesday, .full): return "Tuesday"
        case (.wednesday, .full): return "Wednesday"
        case (.thursday, .full): return "Thursday"
        case (.friday, .full): return "Friday"
        case (.saturday, .full): return "Saturday"
        case (.sunday, .full): return "Sunday"
        case (.monday, .chip): return "Mon"
        case (.tuesday, .chip): return "Tue"
        case (.wednesday, .chip): return "Wed"
        case (.thursday, .chip): return "Thu"
        case (.friday, .chip): return "Fri"
        case (.saturday, .chip): return "Sat"
        case (.sunday, .chip): return "Sun"
        case (.monday, .letter): return "M"
        case (.tuesday, .letter): return "T"
        case (.wednesday, .letter): return "W"
        case (.thursday, .letter): return "T"
        case (.friday, .letter): return "F"
        case (.saturday, .letter): return "S"
        case (.sunday, .letter): return "S"
        default: return ""
        }
    }
    
    private func islamicWeekdayName(_ weekday: WeekdaySet, style: WeekdayNameStyle) -> String {
        switch (weekday, style) {
        case (.sunday, .full): return "Al-Ahad"
        case (.monday, .full): return "Al-Ithnayn"
        case (.tuesday, .full): return "Ath-Thulatha"
        case (.wednesday, .full): return "Al-Arbi‘a"
        case (.thursday, .full): return "Al-Khamis"
        case (.friday, .full): return "Al-Jumu‘ah"
        case (.saturday, .full): return "As-Sabt"
        case (.sunday, .chip): return "Ahad"
        case (.monday, .chip): return "Ithnayn"
        case (.tuesday, .chip): return "Thulatha"
        case (.wednesday, .chip): return "Arbi‘a"
        case (.thursday, .chip): return "Khamis"
        case (.friday, .chip): return "Jumu‘ah"
        case (.saturday, .chip): return "Sabt"
        case (.sunday, .letter): return "A"
        case (.monday, .letter): return "I"
        case (.tuesday, .letter): return "T"
        case (.wednesday, .letter): return "R"
        case (.thursday, .letter): return "K"
        case (.friday, .letter): return "J"
        case (.saturday, .letter): return "S"
        default: return ""
        }
    }
    
    // MARK: - Formatters
    
    private var gregorianLong: DateFormatter {
        Self.formatter("MMM d, yyyy", calendar: gregorianCalendar)
    }
    
    private var gregorianShort: DateFormatter {
        Self.formatter("MMM d", calendar: gregorianCalendar)
    }
    
    private var gregorianMonthYear: DateFormatter {
        Self.formatter("MMMM yyyy", calendar: gregorianCalendar)
    }
    
    private var gregorianDay: DateFormatter {
        Self.formatter("d", calendar: gregorianCalendar)
    }
    
    private var hijriLong: DateFormatter {
        Self.formatter("d MMMM y", calendar: hijriCalendar)
    }
    
    private var hijriShort: DateFormatter {
        Self.formatter("d MMM", calendar: hijriCalendar)
    }
    
    private var hijriMonthYear: DateFormatter {
        Self.formatter("MMMM y", calendar: hijriCalendar)
    }
    
    private var hijriDay: DateFormatter {
        Self.formatter("d", calendar: hijriCalendar)
    }
    
    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
    
    private func hijriMonthSpan(inGregorianMonthOf date: Date) -> String {
        let greg = gregorianCalendar
        guard let monthStart = greg.date(from: greg.dateComponents([.year, .month], from: date)),
              let range = greg.range(of: .day, in: .month, for: monthStart),
              let monthEnd = greg.date(byAdding: .day, value: range.count - 1, to: monthStart)
        else {
            return hijriMonthYear.string(from: date)
        }
        let startName = hijriMonthYear.string(from: monthStart)
        let endName = hijriMonthYear.string(from: monthEnd)
        return startName == endName ? startName : "\(startName) / \(endName)"
    }
    
    private func paddedMonthDays(calendar: Calendar, containing date: Date) -> [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in range {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(GoalEntry.startOfCivilDay(for: dayDate))
            }
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }
}
