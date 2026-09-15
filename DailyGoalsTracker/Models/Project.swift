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

// MARK: - Milestone

struct Milestone: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var completedAt: Date?
    var order: Int
    
    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.order = order
    }
    
    mutating func toggle() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }
}

// MARK: - Project

struct Project: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var plan: String                    // Markdown plan/notes
    var startDate: Date
    var targetDate: Date?               // Optional deadline
    var status: ProjectStatus
    var linkedGoalIds: [UUID]           // Daily tasks that contribute
    var targetCount: Int?               // e.g., "Exercise 100 times"
    var milestones: [Milestone]
    var createdAt: Date
    var completedAt: Date?
    var order: Int
    var colorName: String               // For visual distinction
    var icon: String                    // SF Symbol
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        plan: String = "",
        startDate: Date = Date(),
        targetDate: Date? = nil,
        status: ProjectStatus = .active,
        linkedGoalIds: [UUID] = [],
        targetCount: Int? = nil,
        milestones: [Milestone] = [],
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
        self.linkedGoalIds = linkedGoalIds
        self.targetCount = targetCount
        self.milestones = milestones
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
    
    var hasLinkedGoals: Bool {
        !linkedGoalIds.isEmpty
    }
    
    var hasMilestones: Bool {
        !milestones.isEmpty
    }
    
    var hasTargetCount: Bool {
        targetCount != nil && targetCount! > 0
    }
    
    // MARK: - Milestone Progress
    
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
    
    /// The date range for counting daily task completions.
    var dateRange: ClosedRange<Date> {
        let end = targetDate ?? Date()
        return startDate...end
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
    
    mutating func toggleMilestone(id: UUID) {
        guard let index = milestones.firstIndex(where: { $0.id == id }) else { return }
        milestones[index].toggle()
    }
    
    mutating func addMilestone(_ title: String) {
        let order = (milestones.map(\.order).max() ?? -1) + 1
        milestones.append(Milestone(title: title, order: order))
    }
    
    mutating func removeMilestone(id: UUID) {
        milestones.removeAll { $0.id == id }
    }
    
    mutating func reorderMilestones(from source: IndexSet, to destination: Int) {
        milestones.move(fromOffsets: source, toOffset: destination)
        for (index, _) in milestones.enumerated() {
            milestones[index].order = index
        }
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

// MARK: - Progress Calculation Result

struct ProjectProgress {
    let linkedCompletions: Int      // Count of daily task completions
    let targetCount: Int?           // Target count if set
    let completedMilestones: Int
    let totalMilestones: Int
    
    /// Overall progress percentage (0-1) combining both metrics
    var overallProgress: Double {
        var weights: [(progress: Double, weight: Double)] = []
        
        // Add linked goal progress if applicable
        if let target = targetCount, target > 0 {
            let goalProgress = min(Double(linkedCompletions) / Double(target), 1.0)
            weights.append((goalProgress, 1.0))
        }
        
        // Add milestone progress if applicable
        if totalMilestones > 0 {
            let milestoneProgress = Double(completedMilestones) / Double(totalMilestones)
            weights.append((milestoneProgress, 1.0))
        }
        
        // If no metrics, return 0
        guard !weights.isEmpty else { return 0 }
        
        // Weighted average (equal weights for now)
        let totalWeight = weights.reduce(0) { $0 + $1.weight }
        let weightedSum = weights.reduce(0) { $0 + $1.progress * $1.weight }
        return weightedSum / totalWeight
    }
    
    var linkedProgressPercent: Int {
        guard let target = targetCount, target > 0 else { return 0 }
        return Int(min(Double(linkedCompletions) / Double(target), 1.0) * 100)
    }
    
    var milestoneProgressPercent: Int {
        guard totalMilestones > 0 else { return 0 }
        return Int(Double(completedMilestones) / Double(totalMilestones) * 100)
    }
    
    var overallProgressPercent: Int {
        Int(overallProgress * 100)
    }
}
