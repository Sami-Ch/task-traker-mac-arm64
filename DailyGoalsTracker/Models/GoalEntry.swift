import Foundation

/// Represents a goal's status for a specific date
struct GoalEntry: Identifiable, Codable, Equatable {
    var id: String { "\(goalId.uuidString)_\(dateString)" }
    let goalId: UUID
    let date: Date
    var status: GoalStatus
    var note: String?
    /// 0–100 when this day was logged as a percent task. Nil keeps the checklist fallback.
    var percent: Int?
    /// Today's count when this day was logged as a count task.
    var amount: Int?
    
    /// Date formatted as string for storage key
    var dateString: String {
        Self.dateFormatter.string(from: date)
    }
    
    init(
        goalId: UUID,
        date: Date,
        status: GoalStatus = .notDone,
        note: String? = nil,
        percent: Int? = nil,
        amount: Int? = nil
    ) {
        self.goalId = goalId
        self.date = Self.startOfCivilDay(for: date)
        self.status = status
        self.note = note
        self.percent = percent
        self.amount = amount
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goalId = try c.decode(UUID.self, forKey: .goalId)
        date = try c.decode(Date.self, forKey: .date)
        status = try c.decodeIfPresent(GoalStatus.self, forKey: .status) ?? .notDone
        note = try c.decodeIfPresent(String.self, forKey: .note)
        percent = try c.decodeIfPresent(Int.self, forKey: .percent)
        amount = try c.decodeIfPresent(Int.self, forKey: .amount)
    }
    
    /// 0–1 contribution of this day. Days never logged with the current type fall back to checklist status.
    func progressValue(for goal: Goal) -> Double {
        switch goal.kind {
        case .checklist:
            return status.value
        case .percent:
            return Double(resolvedPercent) / 100
        case .count:
            guard amount != nil else { return status.value }
            return goal.loggedProgress(resolvedAmount(for: goal))
        case .hours:
            if amount == nil {
                return goal.hourBound == .atMost ? 1 : status.value
            }
            return goal.loggedProgress(resolvedAmount(for: goal))
        }
    }
    
    var resolvedPercent: Int {
        if let percent { return min(100, max(0, percent)) }
        return Int((status.value * 100).rounded())
    }
    
    func resolvedAmount(for goal: Goal) -> Int {
        if let amount { return max(0, amount) }
        if goal.kind == .hours && goal.hourBound == .atMost { return 0 }
        let scale: Int
        if goal.kind == .hours {
            scale = goal.hourMinimum ?? goal.safeTargetMinutes
        } else {
            scale = goal.safeTarget
        }
        return Int((status.value * Double(scale)).rounded())
    }
    
    func progressDescription(for goal: Goal) -> String {
        switch goal.kind {
        case .checklist:
            return status.accessibilityLabel
        case .percent:
            return "\(resolvedPercent) percent"
        case .count:
            let current = resolvedAmount(for: goal)
            if goal.trimmedUnit.isEmpty { return "\(current) of \(goal.safeTarget)" }
            return "\(current) of \(goal.safeTarget) \(goal.trimmedUnit)"
        case .hours:
            let currentMinutes = resolvedAmount(for: goal)
            let current = Goal.formatMinutes(currentMinutes)
            if goal.isOverHourLimit(currentMinutes), let ceiling = goal.hourMaximum {
                return "\(current), over \(Goal.formatMinutes(ceiling))"
            }
            switch goal.hourBound {
            case .atMost:
                return "\(current) of \(Goal.formatMinutes(goal.safeTargetMinutes)), within the limit"
            case .between:
                return "\(current), between \(Goal.formatMinutes(goal.safeFloorMinutes)) and \(Goal.formatMinutes(goal.safeTargetMinutes))"
            case .atLeast:
                return "\(current) of \(Goal.formatMinutes(goal.safeTargetMinutes))"
            }
        }
    }
    
    func weekHelp(for goal: Goal) -> String {
        switch goal.kind {
        case .checklist:
            return status.accessibilityLabel
        case .percent:
            return "\(resolvedPercent)%"
        case .count, .hours:
            return progressDescription(for: goal)
        }
    }
    
    // MARK: - Date Formatting
    
    /// Persistence keys stay Gregorian even when the UI shows Hijri.
    static func startOfCivilDay(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar.startOfDay(for: date)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
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
    /// 0–1 progress for each tracked task, parallel to `entries`.
    let progressValues: [Double]
    let totalGoals: Int
    let dayMode: DayMode
    let skippedCount: Int
    
    var completionPercentage: Double {
        guard totalGoals > 0 else { return dayMode.tracksEssentialOnly ? 1.0 : 0 }
        let total = progressValues.reduce(0, +)
        return total / Double(totalGoals)
    }
    
    var doneCount: Int {
        progressValues.filter { $0 >= 1 }.count
    }
    
    var partialCount: Int {
        progressValues.filter { $0 > 0 && $0 < 1 }.count
    }
    
    var notDoneCount: Int {
        totalGoals - doneCount - partialCount
    }
    
    var isSpecialDay: Bool {
        dayMode.tracksEssentialOnly
    }
}
