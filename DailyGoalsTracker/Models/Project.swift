import SwiftUI

// MARK: - Project Status

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case paused
    case completed
    case archived
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
    
    var icon: String {
        switch self {
        case .active: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .archived: return .gray
        }
    }
}

// MARK: - Milestone Goal Link

/// A daily task linked to a milestone, with an optional completion target.
struct MilestoneGoalLink: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var goalId: UUID
    var targetCount: Int?
    
    init(id: UUID = UUID(), goalId: UUID, targetCount: Int? = nil) {
        self.id = id
        self.goalId = goalId
        self.targetCount = targetCount
    }
    
    var hasTarget: Bool {
        guard let targetCount else { return false }
        return targetCount > 0
    }
}

// MARK: - Milestone

struct Milestone: Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var completedAt: Date?
    var order: Int
    var linkedGoals: [MilestoneGoalLink]
    /// Set when the user manually uncompletes while targets are still met.
    var suppressAutoComplete: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        order: Int = 0,
        linkedGoals: [MilestoneGoalLink] = [],
        suppressAutoComplete: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.order = order
        self.linkedGoals = linkedGoals
        self.suppressAutoComplete = suppressAutoComplete
    }
    
    var hasLinkedGoals: Bool {
        !linkedGoals.isEmpty
    }
    
    var linkedGoalIds: [UUID] {
        linkedGoals.map(\.goalId)
    }
    
    mutating func markCompleted(auto: Bool = false) {
        isCompleted = true
        completedAt = Date()
        if auto {
            suppressAutoComplete = false
        }
    }
    
    mutating func markIncomplete(suppressAuto: Bool) {
        isCompleted = false
        completedAt = nil
        suppressAutoComplete = suppressAuto
    }
}

extension Milestone: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, completedAt, order, linkedGoals, suppressAutoComplete
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        linkedGoals = try container.decodeIfPresent([MilestoneGoalLink].self, forKey: .linkedGoals) ?? []
        suppressAutoComplete = try container.decodeIfPresent(Bool.self, forKey: .suppressAutoComplete) ?? false
    }
}

// MARK: - Project

struct Project: Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var plan: String
    var startDate: Date
    var targetDate: Date?
    var status: ProjectStatus
    var milestones: [Milestone]
    var alerts: [ProjectAlert]
    var createdAt: Date
    var completedAt: Date?
    var order: Int
    var colorName: String
    var icon: String
    
    /// Legacy fields kept only for migration from older JSON; not written on save.
    private var legacyLinkedGoalIds: [UUID] = []
    private var legacyTargetCount: Int? = nil
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        plan: String = "",
        startDate: Date = Date(),
        targetDate: Date? = nil,
        status: ProjectStatus = .active,
        milestones: [Milestone] = [],
        alerts: [ProjectAlert] = [],
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        order: Int = 0,
        colorName: String = "blue",
        icon: String = "flag.fill"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.plan = plan
        self.startDate = startDate
        self.targetDate = targetDate
        self.status = status
        self.milestones = milestones
        self.alerts = alerts
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.order = order
        self.colorName = colorName
        self.icon = icon
    }
    
    // MARK: - Computed Properties
    
    var color: Color {
        ProjectColorName(rawValue: colorName)?.color ?? .blue
    }
    
    var isActive: Bool {
        status == .active
    }
    
    var isPaused: Bool {
        status == .paused
    }
    
    var isCompleted: Bool {
        status == .completed
    }
    
    var isArchived: Bool {
        status == .archived
    }
    
    var hasDeadline: Bool {
        targetDate != nil
    }
    
    var hasMilestones: Bool {
        !milestones.isEmpty
    }
    
    /// Civil start-of-day has arrived (or passed).
    var hasStarted: Bool {
        let today = GoalEntry.startOfCivilDay(for: Date())
        let start = GoalEntry.startOfCivilDay(for: startDate)
        return start <= today
    }
    
    /// Active/paused project whose start date is still in the future.
    var isUpcoming: Bool {
        (isActive || isPaused) && !hasStarted
    }
    
    var allLinkedGoalIds: [UUID] {
        milestones.flatMap(\.linkedGoalIds)
    }
    
    var hasLinkedGoals: Bool {
        !allLinkedGoalIds.isEmpty
    }
    
    var projectScopedAlerts: [ProjectAlert] {
        alerts.filter { $0.milestoneId == nil }
    }
    
    func alerts(forMilestoneId milestoneId: UUID) -> [ProjectAlert] {
        alerts.filter { $0.milestoneId == milestoneId }
    }
    
    // MARK: - Milestone Progress (stored flags only)
    
    var completedMilestones: Int {
        milestones.filter(\.isCompleted).count
    }
    
    var totalMilestones: Int {
        milestones.count
    }
    
    var milestoneProgress: Double {
        guard totalMilestones > 0 else { return 0 }
        return Double(completedMilestones) / Double(totalMilestones)
    }
    
    var nextMilestone: Milestone? {
        milestones
            .filter { !$0.isCompleted }
            .sorted { $0.order < $1.order }
            .first
    }
    
    // MARK: - Date Range
    
    /// Inclusive range for counting daily-task completions.
    /// Collapses to a single instant when the project has not started yet so
    /// Swift never traps on an inverted `ClosedRange`.
    var dateRange: ClosedRange<Date> {
        let today = Date()
        let endLimit = min(targetDate ?? today, today)
        if startDate <= endLimit {
            return startDate...endLimit
        }
        return startDate...startDate
    }
    
    // MARK: - Mutations
    
    mutating func complete() {
        status = .completed
        completedAt = Date()
    }
    
    mutating func reopen() {
        status = .active
        completedAt = nil
    }
    
    mutating func pause() {
        status = .paused
    }
    
    mutating func archive() {
        status = .archived
    }
    
    mutating func toggleMilestone(id: UUID, autoAchieved: Bool = false) {
        guard let index = milestones.firstIndex(where: { $0.id == id }) else { return }
        let wasCompleted = milestones[index].isCompleted
        if wasCompleted {
            // Manual uncomplete — suppress auto if targets still met
            milestones[index].markIncomplete(suppressAuto: autoAchieved)
        } else {
            milestones[index].markCompleted(auto: false)
        }
    }
    
    mutating func addMilestone(_ title: String) {
        let order = (milestones.map(\.order).max() ?? -1) + 1
        milestones.append(Milestone(title: title, order: order))
    }
    
    mutating func removeMilestone(id: UUID) {
        milestones.removeAll { $0.id == id }
        removeAlerts(forMilestoneId: id)
    }
    
    mutating func reorderMilestones(from source: IndexSet, to destination: Int) {
        milestones.move(fromOffsets: source, toOffset: destination)
        for (index, _) in milestones.enumerated() {
            milestones[index].order = index
        }
    }
    
    mutating func updateMilestone(_ milestone: Milestone) {
        guard let index = milestones.firstIndex(where: { $0.id == milestone.id }) else { return }
        milestones[index] = milestone
    }
    
    mutating func addAlert(_ alert: ProjectAlert) {
        alerts.append(alert)
    }
    
    mutating func updateAlert(_ alert: ProjectAlert) {
        guard let index = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[index] = alert
    }
    
    mutating func removeAlert(id: UUID) {
        alerts.removeAll { $0.id == id }
    }
    
    mutating func removeAlerts(forMilestoneId milestoneId: UUID) {
        alerts.removeAll { $0.milestoneId == milestoneId }
    }
    
    /// Fold legacy project-level linked goals into a milestone (idempotent).
    mutating func migrateLegacyLinkedGoalsIfNeeded() {
        guard !legacyLinkedGoalIds.isEmpty else { return }
        
        let links = legacyLinkedGoalIds.map { goalId in
            MilestoneGoalLink(goalId: goalId, targetCount: legacyTargetCount)
        }
        
        if let index = milestones.indices.first {
            let existingIds = Set(milestones[index].linkedGoals.map(\.goalId))
            for link in links where !existingIds.contains(link.goalId) {
                milestones[index].linkedGoals.append(link)
            }
        } else {
            milestones.append(Milestone(
                title: "Progress",
                order: 0,
                linkedGoals: links
            ))
        }
        
        legacyLinkedGoalIds = []
        legacyTargetCount = nil
    }
}

// MARK: - Codable

extension Project: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, description, plan, startDate, targetDate, status
        case milestones, alerts, createdAt, completedAt, order, colorName, icon
        case linkedGoalIds, targetCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        plan = try container.decodeIfPresent(String.self, forKey: .plan) ?? ""
        startDate = try container.decode(Date.self, forKey: .startDate)
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate)
        status = try container.decode(ProjectStatus.self, forKey: .status)
        milestones = try container.decodeIfPresent([Milestone].self, forKey: .milestones) ?? []
        alerts = try container.decodeIfPresent([ProjectAlert].self, forKey: .alerts) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        colorName = try container.decodeIfPresent(String.self, forKey: .colorName) ?? "blue"
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "flag.fill"
        legacyLinkedGoalIds = try container.decodeIfPresent([UUID].self, forKey: .linkedGoalIds) ?? []
        legacyTargetCount = try container.decodeIfPresent(Int.self, forKey: .targetCount)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(plan, forKey: .plan)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(targetDate, forKey: .targetDate)
        try container.encode(status, forKey: .status)
        try container.encode(milestones, forKey: .milestones)
        try container.encode(alerts, forKey: .alerts)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(order, forKey: .order)
        try container.encode(colorName, forKey: .colorName)
        try container.encode(icon, forKey: .icon)
        // Intentionally omit legacy linkedGoalIds / targetCount
    }
}

// MARK: - Project Color

enum ProjectColorName: String, CaseIterable, Identifiable, Codable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal
    case gray
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return Color(red: 0.85, green: 0.65, blue: 0)
        case .green: return .green
        case .teal: return .teal
        case .gray: return .gray
        }
    }
    
    var label: String {
        rawValue.capitalized
    }
}

// MARK: - Progress Calculation Results

struct MilestoneGoalProgress: Identifiable, Equatable {
    var id: UUID { linkId }
    let linkId: UUID
    let goalId: UUID
    let count: Double
    let targetCount: Int?
    
    var hasTarget: Bool {
        guard let targetCount else { return false }
        return targetCount > 0
    }
    
    var isTargetMet: Bool {
        guard let targetCount, targetCount > 0 else { return false }
        return count + 0.0001 >= Double(targetCount)
    }
    
    var progressFraction: Double {
        guard let targetCount, targetCount > 0 else { return 0 }
        return min(count / Double(targetCount), 1.0)
    }
}

struct MilestoneProgress: Equatable {
    let milestoneId: UUID
    let goalProgress: [MilestoneGoalProgress]
    let isAutoAchieved: Bool
    let isEffectivelyComplete: Bool
    
    var targetsMetCount: Int {
        goalProgress.filter(\.isTargetMet).count
    }
    
    var targetsTotalCount: Int {
        goalProgress.filter(\.hasTarget).count
    }
}

struct ProjectProgress {
    let completedMilestones: Int
    let totalMilestones: Int
    let milestoneDetails: [MilestoneProgress]
    let hasStarted: Bool
    
    var overallProgress: Double {
        guard hasStarted, totalMilestones > 0 else { return 0 }
        return Double(completedMilestones) / Double(totalMilestones)
    }
    
    var overallProgressPercent: Int {
        Int(overallProgress * 100)
    }
    
    func detail(for milestoneId: UUID) -> MilestoneProgress? {
        milestoneDetails.first { $0.milestoneId == milestoneId }
    }
}
