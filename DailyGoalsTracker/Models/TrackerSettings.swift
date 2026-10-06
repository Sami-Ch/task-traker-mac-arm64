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
    /// Weekly and monthly progress reports.
    var periodReportsEnabled: Bool
    /// Minutes of no typing or clicking before an unlocked journal locks again. 0 means only when the window closes.
    var journalAutoLockMinutes: Int
    
    static let journalAutoLockChoices = [5, 15, 30, 60, 120, 240]
    
    static let `default` = TrackerSettings(
        calendarDisplay: .gregorian,
        dayStartMinutes: 0,
        dayEndMinutes: 23 * 60 + 59,
        dayStartsAtMaghrib: false,
        periodReportsEnabled: true,
        journalAutoLockMinutes: 60
    )
    
    init(
        calendarDisplay: CalendarDisplayMode = .gregorian,
        dayStartMinutes: Int = 0,
        dayEndMinutes: Int = 23 * 60 + 59,
        dayStartsAtMaghrib: Bool = false,
        periodReportsEnabled: Bool = true,
        journalAutoLockMinutes: Int = 60
    ) {
        self.calendarDisplay = calendarDisplay
        self.dayStartMinutes = Self.clampedMinutes(dayStartMinutes)
        self.dayEndMinutes = Self.clampedMinutes(dayEndMinutes)
        self.dayStartsAtMaghrib = dayStartsAtMaghrib
        self.periodReportsEnabled = periodReportsEnabled
        self.journalAutoLockMinutes = Self.clampedAutoLock(journalAutoLockMinutes)
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calendarDisplay = try c.decodeIfPresent(CalendarDisplayMode.self, forKey: .calendarDisplay) ?? .gregorian
        dayStartMinutes = Self.clampedMinutes(try c.decodeIfPresent(Int.self, forKey: .dayStartMinutes) ?? 0)
        dayEndMinutes = Self.clampedMinutes(try c.decodeIfPresent(Int.self, forKey: .dayEndMinutes) ?? (23 * 60 + 59))
        dayStartsAtMaghrib = try c.decodeIfPresent(Bool.self, forKey: .dayStartsAtMaghrib) ?? false
        periodReportsEnabled = try c.decodeIfPresent(Bool.self, forKey: .periodReportsEnabled) ?? true
        journalAutoLockMinutes = Self.clampedAutoLock(try c.decodeIfPresent(Int.self, forKey: .journalAutoLockMinutes) ?? 60)
    }
    
    static func clampedMinutes(_ value: Int) -> Int {
        min(max(value, 0), 23 * 60 + 59)
    }
    
    static func clampedAutoLock(_ value: Int) -> Int {
        journalAutoLockChoices.contains(value) ? value : 60
    }
}
