import Foundation

/// How a task is logged each day.
enum GoalKind: String, Codable, CaseIterable, Identifiable {
    case checklist
    case percent
    case count
    case hours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checklist: return "Checklist"
        case .percent: return "Percent"
        case .count: return "Count"
        case .hours: return "Hours"
        }
    }

    var caption: String {
        switch self {
        case .checklist: return "Tap the circle. Not done, partial, or done."
        case .percent: return "Tap the pill to add a step. Tap the task to open the slider."
        case .count: return "Tap the pill to add the increment. It stops at the max."
        case .hours: return "Tap the pill to add the small step. Tap the task to open the slider."
        }
    }
}

/// Whether an hours task is a minimum, a ceiling, or a window between both.
enum HourBound: String, Codable, CaseIterable, Identifiable {
    case atLeast
    case atMost
    case between

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atLeast: return "At least"
        case .atMost: return "At most"
        case .between: return "Between"
        }
    }

    var caption: String {
        switch self {
        case .atLeast: return "Done once you reach this time, even if you go longer."
        case .atMost: return "Done from zero up to this time. Going over marks it missed."
        case .between: return "Done only while you stay between the two times."
        }
    }
}

/// Represents a recurring goal that the user tracks daily
struct Goal: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var icon: String  // SF Symbol name
    var order: Int
    var isActive: Bool
    var isEssential: Bool
    var weekdays: WeekdaySet
    var kind: GoalKind
    var targetCount: Int
    var unit: String
    /// Count jump size, or the small hour step in minutes.
    var step: Int
    var hourBound: HourBound
    /// Single hours target, or the ceiling when the task uses both limits.
    var targetMinutes: Int
    /// Minimum minutes when the task must also stay under a ceiling.
    var floorMinutes: Int

    init(
        id: UUID = UUID(),
        title: String,
        icon: String = "star.fill",
        order: Int = 0,
        isActive: Bool = true,
        isEssential: Bool = false,
        weekdays: WeekdaySet = .all,
        kind: GoalKind = .checklist,
        targetCount: Int = 1,
        unit: String = "",
        step: Int = 1,
        hourBound: HourBound = .atLeast,
        targetMinutes: Int = 60,
        floorMinutes: Int = 0
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.order = order
        self.isActive = isActive
        self.isEssential = isEssential
        self.weekdays = weekdays
        self.kind = kind
        self.targetCount = Self.clampedTarget(targetCount)
        self.unit = unit
        self.step = step
        self.hourBound = hourBound
        self.targetMinutes = Self.clampedMinutes(targetMinutes)
        self.floorMinutes = max(0, floorMinutes)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        icon = try c.decode(String.self, forKey: .icon)
        order = try c.decode(Int.self, forKey: .order)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        isEssential = try c.decodeIfPresent(Bool.self, forKey: .isEssential) ?? false
        weekdays = try c.decodeIfPresent(WeekdaySet.self, forKey: .weekdays) ?? .all
        kind = try c.decodeIfPresent(GoalKind.self, forKey: .kind) ?? .checklist
        targetCount = Self.clampedTarget(try c.decodeIfPresent(Int.self, forKey: .targetCount) ?? 1)
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
        step = try c.decodeIfPresent(Int.self, forKey: .step) ?? 1
        hourBound = try c.decodeIfPresent(HourBound.self, forKey: .hourBound) ?? .atLeast
        targetMinutes = Self.clampedMinutes(
            try c.decodeIfPresent(Int.self, forKey: .targetMinutes) ?? 60)
        floorMinutes = max(0, try c.decodeIfPresent(Int.self, forKey: .floorMinutes) ?? 0)
    }

    var trimmedUnit: String {
        unit.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var safeTarget: Int { max(1, targetCount) }

    /// Percent added by each tap on the pill. 1 is treated as the default, 10.
    var safePercentStep: Int {
        let raw = step <= 1 ? 10 : step
        return min(100, max(1, raw))
    }

    /// Count added by each tap on the pill.
    var safeCountStep: Int { Self.clampedStep(step, target: safeTarget) }

    var safeTargetMinutes: Int { Self.clampedMinutes(targetMinutes) }

    /// Lower bound used when a task must land between two times.
    var safeFloorMinutes: Int {
        let floor = floorMinutes > 0 ? floorMinutes : 30
        return min(safeTargetMinutes, Self.clampedMinutes(floor))
    }

    var hourMinimum: Int? {
        switch hourBound {
        case .atLeast: return safeTargetMinutes
        case .between: return safeFloorMinutes
        case .atMost: return nil
        }
    }

    var hourMaximum: Int? {
        switch hourBound {
        case .atMost, .between: return safeTargetMinutes
        case .atLeast: return nil
        }
    }

    /// Small time step: 1, 5, 10, 15, or 30 minutes.
    var safeHourStep: Int { Self.clampedHourStep(step) }

    var rowCaption: String? {
        switch kind {
        case .count:
            return trimmedUnit.isEmpty ? nil : trimmedUnit
        case .hours:
            switch hourBound {
            case .atLeast:
                return "At least \(Self.formatMinutes(safeTargetMinutes))"
            case .atMost:
                return "Limit \(Self.formatMinutes(safeTargetMinutes))"
            case .between:
                return "\(Self.formatMinutes(safeFloorMinutes)) – \(Self.formatMinutes(safeTargetMinutes))"
            }
        case .checklist, .percent:
            return nil
        }
    }

    /// Library subtitle: "Checklist", "Percent", "Count · 100 · +10", or "Hours · at least 1h".
    var trackingSubtitle: String {
        switch kind {
        case .checklist: return GoalKind.checklist.title
        case .percent: return GoalKind.percent.title
        case .count:
            if trimmedUnit.isEmpty { return "Count · \(safeTarget)" }
            return "Count · \(safeTarget) \(trimmedUnit)"
        case .hours:
            switch hourBound {
            case .atLeast: return "Hours · at least \(Self.formatMinutes(safeTargetMinutes))"
            case .atMost: return "Hours · at most \(Self.formatMinutes(safeTargetMinutes))"
            case .between:
                return "Hours · \(Self.formatMinutes(safeFloorMinutes)) – \(Self.formatMinutes(safeTargetMinutes))"
            }
        }
    }

    /// 0–1 score for a logged count or a logged number of minutes.
    func loggedProgress(_ logged: Int) -> Double {
        let value = max(0, logged)
        switch kind {
        case .hours:
            if let ceiling = hourMaximum, value > ceiling { return 0 }
            if let floor = hourMinimum {
                if value >= floor { return 1 }
                return Double(value) / Double(max(1, floor))
            }
            return 1
        case .count:
            return min(1, Double(value) / Double(safeTarget))
        case .checklist, .percent:
            return 0
        }
    }

    func isOverHourLimit(_ logged: Int) -> Bool {
        guard kind == .hours, let ceiling = hourMaximum else { return false }
        return logged > ceiling
    }

    /// Step stored for this tracking type. A percent step is not limited by the count max.
    static func storedStep(kind: GoalKind, step: Int, targetCount: Int) -> Int {
        switch kind {
        case .hours: return clampedHourStep(step)
        case .percent: return min(100, max(1, step))
        case .count: return clampedStep(step, target: targetCount)
        case .checklist: return max(1, step)
        }
    }

    static func clampedTarget(_ value: Int) -> Int {
        min(9999, max(1, value))
    }

    static func clampedStep(_ value: Int, target: Int) -> Int {
        min(max(1, target), max(1, value))
    }

    static func clampedMinutes(_ value: Int) -> Int {
        min(24 * 60, max(15, value))
    }

    static func clampedHourStep(_ value: Int) -> Int {
        let choices = [1, 5, 10, 15, 30]
        return choices.min { abs($0 - value) < abs($1 - value) } ?? 15
    }

    static func formatMinutes(_ minutes: Int) -> String {
        let value = max(0, minutes)
        let hours = value / 60
        let remainder = value % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}

// MARK: - Sample Goals
extension Goal {
    static let samples: [Goal] = [
        Goal(title: "Exercise", icon: "figure.run", order: 0),
        Goal(title: "Read", icon: "book.fill", order: 1),
        Goal(title: "Meditate", icon: "brain.head.profile", order: 2),
        Goal(title: "Healthy Eating", icon: "leaf.fill", order: 3),
        Goal(title: "Learn Something New", icon: "lightbulb.fill", order: 4),
        Goal(title: "Connect with Family", icon: "heart.fill", order: 5),
        Goal(title: "Work on Side Project", icon: "hammer.fill", order: 6),
        Goal(title: "Drink Water", icon: "drop.fill", order: 7),
    ]
}
