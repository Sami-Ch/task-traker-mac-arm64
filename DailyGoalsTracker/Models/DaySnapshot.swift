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
    
    init(goalId: UUID, title: String, icon: String, order: Int, isOverride: Bool = false, isOneOff: Bool = false) {
        self.goalId = goalId
        self.title = title
        self.icon = icon
        self.order = order
        self.isOverride = isOverride
        self.isOneOff = isOneOff
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goalId = try c.decode(UUID.self, forKey: .goalId)
        title = try c.decode(String.self, forKey: .title)
        icon = try c.decode(String.self, forKey: .icon)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        isOverride = try c.decodeIfPresent(Bool.self, forKey: .isOverride) ?? false
        isOneOff = try c.decodeIfPresent(Bool.self, forKey: .isOneOff) ?? false
    }
    
    func asGoal() -> Goal {
        Goal(id: goalId, title: title, icon: icon, order: order, isActive: true)
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
