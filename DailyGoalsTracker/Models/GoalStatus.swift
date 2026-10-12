import SwiftUI

/// Represents the completion status of a goal for a specific day
enum GoalStatus: String, Codable, CaseIterable {
    case notDone = "not_done"
    case partial = "partial"
    case done = "done"
    
    /// Cycle to the next status (for tap-to-change interaction)
    var next: GoalStatus {
        switch self {
        case .notDone: return .partial
        case .partial: return .done
        case .done: return .notDone
        }
    }
    
    /// SF Symbol name for the status
    var iconName: String {
        switch self {
        case .notDone: return "circle"
        case .partial: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        }
    }
    
    /// Color representing the status
    var color: Color {
        switch self {
        case .notDone: return .gray.opacity(0.4)
        case .partial: return .orange
        case .done: return .green
        }
    }
    
    /// Numeric value for calculations (0-1 scale)
    var value: Double {
        switch self {
        case .notDone: return 0.0
        case .partial: return 0.5
        case .done: return 1.0
        }
    }
    
    /// Accessibility label
    var accessibilityLabel: String {
        switch self {
        case .notDone: return "Not completed"
        case .partial: return "Partially completed"
        case .done: return "Completed"
        }
    }
    
    /// Coarse status for a 0–1 progress value.
    static func from(progress: Double) -> GoalStatus {
        if progress <= 0 { return .notDone }
        if progress >= 1 { return .done }
        return .partial
    }
    
    /// Gray at zero, orange while in progress, green when complete.
    static func tint(for progress: Double) -> Color {
        if progress <= 0 { return .gray.opacity(0.45) }
        if progress >= 1 { return .green }
        if progress < 0.5 { return .orange }
        return .green.opacity(0.85)
    }
}
