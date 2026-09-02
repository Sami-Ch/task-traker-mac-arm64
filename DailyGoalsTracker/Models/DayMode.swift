import SwiftUI

/// How a day is treated for tracking — normal or a special context.
enum DayMode: String, Codable, CaseIterable, Identifiable {
    case normal = "normal"
    case fasting = "fasting"
    case trip = "trip"
    case sick = "sick"
    case rest = "rest"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .normal: return "Normal"
        case .fasting: return "Fasting"
        case .trip: return "On Trip"
        case .sick: return "Sick Day"
        case .rest: return "Rest Day"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .normal: return "Normal"
        case .fasting: return "Fasting"
        case .trip: return "Trip"
        case .sick: return "Sick"
        case .rest: return "Rest"
        }
    }
    
    var icon: String {
        switch self {
        case .normal: return "calendar"
        case .fasting: return "moon.stars.fill"
        case .trip: return "airplane"
        case .sick: return "bed.double.fill"
        case .rest: return "leaf.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .normal: return .blue
        case .fasting: return .purple
        case .trip: return .cyan
        case .sick: return .orange
        case .rest: return .green
        }
    }
    
    /// Only essential goals are tracked on special days.
    var tracksEssentialOnly: Bool {
        self != .normal
    }
}

/// Per-day settings (special mode, optional note).
struct DayRecord: Identifiable, Codable, Equatable {
    var id: String { dateString }
    let date: Date
    var mode: DayMode
    var note: String?
    
    var dateString: String {
        GoalEntry.dateString(from: date)
    }
    
    init(date: Date, mode: DayMode = .normal, note: String? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.mode = mode
        self.note = note
    }
}
