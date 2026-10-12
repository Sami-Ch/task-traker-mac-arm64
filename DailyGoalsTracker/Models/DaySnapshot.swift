import Foundation

/// A goal row as it counted on a specific date (copied at freeze so later edits do not rewrite history).
struct SnapshotItem: Identifiable, Codable, Equatable {
    var id: UUID { goalId }
    let goalId: UUID
    var title: String
    var icon: String
    var order: Int
    var isOverride: Bool
    var isOneOff: Bool
    var kind: GoalKind
    var targetCount: Int
    var unit: String
    var step: Int
    var hourBound: HourBound
    var targetMinutes: Int
    var floorMinutes: Int
    
    init(
        goalId: UUID,
        title: String,
        icon: String,
        order: Int,
        isOverride: Bool = false,
        isOneOff: Bool = false,
        kind: GoalKind = .checklist,
        targetCount: Int = 1,
        unit: String = "",
        step: Int = 1,
        hourBound: HourBound = .atLeast,
        targetMinutes: Int = 60,
        floorMinutes: Int = 0
    ) {
        self.goalId = goalId
        self.title = title
        self.icon = icon
        self.order = order
        self.isOverride = isOverride
        self.isOneOff = isOneOff
        self.kind = kind
        self.targetCount = Goal.clampedTarget(targetCount)
        self.unit = unit
        self.step = step
        self.hourBound = hourBound
        self.targetMinutes = Goal.clampedMinutes(targetMinutes)
        self.floorMinutes = max(0, floorMinutes)
    }
    
    init(goal: Goal, order: Int, isOverride: Bool = false, isOneOff: Bool = false) {
        self.init(
            goalId: goal.id,
            title: goal.title,
            icon: goal.icon,
            order: order,
            isOverride: isOverride,
            isOneOff: isOneOff,
            kind: goal.kind,
            targetCount: goal.targetCount,
            unit: goal.unit,
            step: goal.step,
            hourBound: goal.hourBound,
            targetMinutes: goal.targetMinutes,
            floorMinutes: goal.floorMinutes
        )
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goalId = try c.decode(UUID.self, forKey: .goalId)
        title = try c.decode(String.self, forKey: .title)
        icon = try c.decode(String.self, forKey: .icon)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        isOverride = try c.decodeIfPresent(Bool.self, forKey: .isOverride) ?? false
        isOneOff = try c.decodeIfPresent(Bool.self, forKey: .isOneOff) ?? false
        kind = try c.decodeIfPresent(GoalKind.self, forKey: .kind) ?? .checklist
        targetCount = Goal.clampedTarget(try c.decodeIfPresent(Int.self, forKey: .targetCount) ?? 1)
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
        step = try c.decodeIfPresent(Int.self, forKey: .step) ?? 1
        hourBound = try c.decodeIfPresent(HourBound.self, forKey: .hourBound) ?? .atLeast
        targetMinutes = Goal.clampedMinutes(try c.decodeIfPresent(Int.self, forKey: .targetMinutes) ?? 60)
        floorMinutes = max(0, try c.decodeIfPresent(Int.self, forKey: .floorMinutes) ?? 0)
    }
    
    func asGoal() -> Goal {
        Goal(
            id: goalId,
            title: title,
            icon: icon,
            order: order,
            isActive: true,
            kind: kind,
            targetCount: targetCount,
            unit: unit,
            step: step,
            hourBound: hourBound,
            targetMinutes: targetMinutes,
            floorMinutes: floorMinutes
        )
    }
}

/// Live overrides (until freeze) plus the frozen row list for a civil date.
struct DaySnapshot: Identifiable, Codable, Equatable {
    var id: String { dateString }
    let dateString: String
    var items: [SnapshotItem]
    var frozen: Bool
    var modeId: String
    var hiddenGoalIds: [UUID]
    var extraGoalIds: [UUID]
    /// Tasks that exist only on this date and are not in the goal library.
    var oneOffItems: [SnapshotItem]
    
    var hiddenSet: Set<UUID> { Set(hiddenGoalIds) }
    var extraSet: Set<UUID> { Set(extraGoalIds) }
    
    init(
        dateString: String,
        items: [SnapshotItem] = [],
        frozen: Bool = false,
        modeId: String = DayMode.normalId,
        hiddenGoalIds: [UUID] = [],
        extraGoalIds: [UUID] = [],
        oneOffItems: [SnapshotItem] = []
    ) {
        self.dateString = dateString
        self.items = items
        self.frozen = frozen
        self.modeId = modeId
        self.hiddenGoalIds = hiddenGoalIds
        self.extraGoalIds = extraGoalIds
        self.oneOffItems = oneOffItems
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dateString = try c.decode(String.self, forKey: .dateString)
        items = try c.decodeIfPresent([SnapshotItem].self, forKey: .items) ?? []
        frozen = try c.decodeIfPresent(Bool.self, forKey: .frozen) ?? false
        modeId = try c.decodeIfPresent(String.self, forKey: .modeId) ?? DayMode.normalId
        hiddenGoalIds = try c.decodeIfPresent([UUID].self, forKey: .hiddenGoalIds) ?? []
        extraGoalIds = try c.decodeIfPresent([UUID].self, forKey: .extraGoalIds) ?? []
        oneOffItems = try c.decodeIfPresent([SnapshotItem].self, forKey: .oneOffItems) ?? []
    }
}
