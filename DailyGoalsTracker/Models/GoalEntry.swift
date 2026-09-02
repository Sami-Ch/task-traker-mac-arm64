import Foundation

/// Represents a goal's status for a specific date
struct GoalEntry: Identifiable, Codable, Equatable {
    var id: String { "\(goalId.uuidString)_\(dateString)" }
    let goalId: UUID
    let date: Date
    var status: GoalStatus
    var note: String?
    
    /// Date formatted as string for storage key
    var dateString: String {
        Self.dateFormatter.string(from: date)
    }
    
    init(goalId: UUID, date: Date, status: GoalStatus = .notDone, note: String? = nil) {
        self.goalId = goalId
        self.date = Calendar.current.startOfDay(for: date)
        self.status = status
        self.note = note
    }
    
    // MARK: - Date Formatting
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static func dateString(from date: Date) -> String {
        dateFormatter.string(from: date)
    }
    
    static func date(from string: String) -> Date? {
        dateFormatter.date(from: string)
    }
}

// MARK: - Daily Summary
struct DailySummary {
    let date: Date
    let entries: [GoalEntry]
    let totalGoals: Int
    let dayMode: DayMode
    let skippedCount: Int
    
    var completionPercentage: Double {
        guard totalGoals > 0 else { return dayMode.tracksEssentialOnly ? 1.0 : 0 }
        let total = entries.reduce(0.0) { $0 + $1.status.value }
        return total / Double(totalGoals)
    }
    
    var doneCount: Int {
        entries.filter { $0.status == .done }.count
    }
    
    var partialCount: Int {
        entries.filter { $0.status == .partial }.count
    }
    
    var notDoneCount: Int {
        totalGoals - doneCount - partialCount
    }
    
    var isSpecialDay: Bool {
        dayMode.tracksEssentialOnly
    }
}
