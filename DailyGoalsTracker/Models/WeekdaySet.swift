import Foundation

/// Civil weekdays stored as bits, Monday = 0 … Sunday = 6.
struct WeekdaySet: OptionSet, Equatable, Hashable, Codable {
    let rawValue: UInt8
    
    static let monday    = WeekdaySet(rawValue: 1 << 0)
    static let tuesday   = WeekdaySet(rawValue: 1 << 1)
    static let wednesday = WeekdaySet(rawValue: 1 << 2)
    static let thursday  = WeekdaySet(rawValue: 1 << 3)
    static let friday    = WeekdaySet(rawValue: 1 << 4)
    static let saturday  = WeekdaySet(rawValue: 1 << 5)
    static let sunday    = WeekdaySet(rawValue: 1 << 6)
    
    static let all = WeekdaySet(rawValue: 0b0111_1111)
    
    static let mondayFirst: [WeekdaySet] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]
    
    static let saturdayFirst: [WeekdaySet] = [
        .saturday, .sunday, .monday, .tuesday, .wednesday, .thursday, .friday
    ]
    
    /// Calendar weekday is 1 = Sunday … 7 = Saturday.
    static func from(calendarWeekday: Int) -> WeekdaySet {
        let bit = (calendarWeekday + 5) % 7
        return WeekdaySet(rawValue: 1 << bit)
    }
    
    static func forDate(_ date: Date, calendar: Calendar = .current) -> WeekdaySet {
        from(calendarWeekday: calendar.component(.weekday, from: date))
    }
    
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        contains(Self.forDate(date, calendar: calendar))
    }
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(UInt8.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
