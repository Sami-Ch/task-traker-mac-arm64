import Foundation

enum CalendarDisplayMode: String, Codable, CaseIterable, Identifiable {
    case gregorian
    case hijri
    case dual
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .gregorian: return "Gregorian"
        case .hijri: return "Hijri"
        case .dual: return "Both"
        }
    }
    
    var usesIslamicWeek: Bool { self != .gregorian }
}

/// User-facing calendar, day bounds, and freeze clock.
struct TrackerSettings: Codable, Equatable {
    var calendarDisplay: CalendarDisplayMode
    /// Minutes from local midnight when the new logical day begins (0…1439).
    var dayStartMinutes: Int
    /// Minutes from local midnight when today's list composition freezes (0…1439).
    var dayEndMinutes: Int
    /// When true, Maghrib (from prayer times) is the day start; falls back to `dayStartMinutes`.
    var dayStartsAtMaghrib: Bool
    
    static let `default` = TrackerSettings(
        calendarDisplay: .gregorian,
        dayStartMinutes: 0,
        dayEndMinutes: 23 * 60 + 59,
        dayStartsAtMaghrib: false
    )
    
    init(
        calendarDisplay: CalendarDisplayMode = .gregorian,
        dayStartMinutes: Int = 0,
        dayEndMinutes: Int = 23 * 60 + 59,
        dayStartsAtMaghrib: Bool = false
    ) {
        self.calendarDisplay = calendarDisplay
        self.dayStartMinutes = Self.clampedMinutes(dayStartMinutes)
        self.dayEndMinutes = Self.clampedMinutes(dayEndMinutes)
        self.dayStartsAtMaghrib = dayStartsAtMaghrib
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calendarDisplay = try c.decodeIfPresent(CalendarDisplayMode.self, forKey: .calendarDisplay) ?? .gregorian
        dayStartMinutes = Self.clampedMinutes(try c.decodeIfPresent(Int.self, forKey: .dayStartMinutes) ?? 0)
        dayEndMinutes = Self.clampedMinutes(try c.decodeIfPresent(Int.self, forKey: .dayEndMinutes) ?? (23 * 60 + 59))
        dayStartsAtMaghrib = try c.decodeIfPresent(Bool.self, forKey: .dayStartsAtMaghrib) ?? false
    }
    
    static func clampedMinutes(_ value: Int) -> Int {
        min(max(value, 0), 23 * 60 + 59)
    }
}
