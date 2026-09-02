import Foundation

/// Represents a recurring goal that the user tracks daily
struct Goal: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var icon: String  // SF Symbol name
    var order: Int
    var isActive: Bool
    var isEssential: Bool
    
    init(id: UUID = UUID(), title: String, icon: String = "star.fill", order: Int = 0, isActive: Bool = true, isEssential: Bool = false) {
        self.id = id
        self.title = title
        self.icon = icon
        self.order = order
        self.isActive = isActive
        self.isEssential = isEssential
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        icon = try c.decode(String.self, forKey: .icon)
        order = try c.decode(Int.self, forKey: .order)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        isEssential = try c.decodeIfPresent(Bool.self, forKey: .isEssential) ?? false
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
        Goal(title: "Drink Water", icon: "drop.fill", order: 7)
    ]
}
