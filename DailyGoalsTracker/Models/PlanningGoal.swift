import Foundation
import SwiftUI

/// Time horizon for planning goals
enum PlanningHorizon: String, Codable, CaseIterable, Identifiable {
    case week = "week"
    case month = "month"
    case year = "year"
    case life = "life"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .life: return "Life Goals"
        }
    }
    
    var icon: String {
        switch self {
        case .week: return "calendar.day.timeline.leading"
        case .month: return "calendar"
        case .year: return "sun.max.fill"
        case .life: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .week: return .blue
        case .month: return .purple
        case .year: return .orange
        case .life: return .yellow
        }
    }
    
    var placeholder: String {
        switch self {
        case .week: return "What do you want to accomplish this week?"
        case .month: return "What are your monthly objectives?"
        case .year: return "What are your goals for this year?"
        case .life: return "What's your ultimate vision?"
        }
    }
    
    /// Period identifier for grouping (e.g., "2026-W35", "2026-09", "2026", "life")
    func periodKey(for date: Date = Date()) -> String {
        let calendar = Calendar.current
        switch self {
        case .week:
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.yearForWeekOfYear, from: date)
            return "\(year)-W\(String(format: "%02d", weekOfYear))"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: date)
        case .year:
            let year = calendar.component(.year, from: date)
            return "\(year)"
        case .life:
            return "life"
        }
    }
}

/// A planning goal for a specific time horizon
struct PlanningGoal: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var horizon: PlanningHorizon
    var periodKey: String  // Which period this goal belongs to
    var isCompleted: Bool
    var order: Int
    var createdAt: Date
    var completedAt: Date?
    var notes: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        horizon: PlanningHorizon,
        periodKey: String? = nil,
        isCompleted: Bool = false,
        order: Int = 0,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.horizon = horizon
        self.periodKey = periodKey ?? horizon.periodKey()
        self.isCompleted = isCompleted
        self.order = order
        self.createdAt = Date()
        self.completedAt = nil
        self.notes = notes
    }
}

// MARK: - Sample Planning Goals
extension PlanningGoal {
    static let samples: [PlanningGoal] = [
        // Week
        PlanningGoal(title: "Complete project milestone", horizon: .week, order: 0),
        PlanningGoal(title: "Exercise 4 times", horizon: .week, order: 1),
        
        // Month  
        PlanningGoal(title: "Read 2 books", horizon: .month, order: 0),
        PlanningGoal(title: "Save $500", horizon: .month, order: 1),
        
        // Year
        PlanningGoal(title: "Learn a new language", horizon: .year, order: 0),
        PlanningGoal(title: "Get promoted", horizon: .year, order: 1),
        
        // Life
        PlanningGoal(title: "Achieve financial freedom", horizon: .life, order: 0),
        PlanningGoal(title: "Travel to 30 countries", horizon: .life, order: 1),
    ]
}
