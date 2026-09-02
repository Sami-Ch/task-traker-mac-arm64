import SwiftUI

/// A user-defined day context (Normal, Fasting, Trip, or custom).
struct DayMode: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var shortTitle: String
    var icon: String
    var colorName: String
    var order: Int
    /// When true, every active goal is tracked (typically the Normal mode).
    var tracksAllGoals: Bool
    /// Goals that count on this mode when `tracksAllGoals` is false.
    var acceptedGoalIds: [UUID]
    
    static let normalId = "normal"
    
    var color: Color {
        ModeColorName(rawValue: colorName)?.color ?? .blue
    }
    
    var isNormal: Bool { id == Self.normalId || tracksAllGoals }
    
    /// Special (non-normal) days only track the accepted goal set.
    var tracksEssentialOnly: Bool { !tracksAllGoals }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        shortTitle: String? = nil,
        icon: String = "star.fill",
        colorName: String = "blue",
        order: Int = 0,
        tracksAllGoals: Bool = false,
        acceptedGoalIds: [UUID] = []
    ) {
        self.id = id
        self.title = title
        let trimmedShort = shortTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.shortTitle = trimmedShort.isEmpty ? String(title.prefix(8)) : trimmedShort
        self.icon = icon
        self.colorName = colorName
        self.order = order
        self.tracksAllGoals = tracksAllGoals
        self.acceptedGoalIds = acceptedGoalIds
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        shortTitle = try c.decodeIfPresent(String.self, forKey: .shortTitle) ?? title
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "star.fill"
        colorName = try c.decodeIfPresent(String.self, forKey: .colorName) ?? "blue"
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        tracksAllGoals = try c.decodeIfPresent(Bool.self, forKey: .tracksAllGoals) ?? (id == Self.normalId)
        acceptedGoalIds = try c.decodeIfPresent([UUID].self, forKey: .acceptedGoalIds) ?? []
    }
    
    static var normalFallback: DayMode {
        DayMode(
            id: normalId,
            title: "Normal",
            shortTitle: "Normal",
            icon: "calendar",
            colorName: "blue",
            order: 0,
            tracksAllGoals: true
        )
    }
    
    /// Seeded defaults matching the previous hardcoded modes.
    static func defaults(acceptedGoalIds: [UUID] = []) -> [DayMode] {
        [
            DayMode(id: normalId, title: "Normal", shortTitle: "Normal", icon: "calendar", colorName: "blue", order: 0, tracksAllGoals: true),
            DayMode(id: "fasting", title: "Fasting", shortTitle: "Fasting", icon: "moon.stars.fill", colorName: "purple", order: 1, acceptedGoalIds: acceptedGoalIds),
            DayMode(id: "trip", title: "On Trip", shortTitle: "Trip", icon: "airplane", colorName: "cyan", order: 2, acceptedGoalIds: acceptedGoalIds),
            DayMode(id: "sick", title: "Sick Day", shortTitle: "Sick", icon: "bed.double.fill", colorName: "orange", order: 3, acceptedGoalIds: acceptedGoalIds),
            DayMode(id: "rest", title: "Rest Day", shortTitle: "Rest", icon: "leaf.fill", colorName: "green", order: 4, acceptedGoalIds: acceptedGoalIds),
        ]
    }
}

/// Named colors for modes (Codable-friendly).
enum ModeColorName: String, CaseIterable, Identifiable {
    case blue, purple, cyan, orange, green, pink, indigo, teal, red, mint
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .cyan: return .cyan
        case .orange: return .orange
        case .green: return .green
        case .pink: return .pink
        case .indigo: return .indigo
        case .teal: return .teal
        case .red: return .red
        case .mint: return .mint
        }
    }
    
    var label: String { rawValue.capitalized }
}

/// Per-day settings (special mode, optional note).
struct DayRecord: Identifiable, Codable, Equatable {
    var id: String { dateString }
    let date: Date
    var modeId: String
    var note: String?
    
    var dateString: String {
        GoalEntry.dateString(from: date)
    }
    
    init(date: Date, modeId: String = DayMode.normalId, note: String? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.modeId = modeId
        self.note = note
    }
    
    enum CodingKeys: String, CodingKey {
        case date, modeId, mode, note
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        if let modeId = try c.decodeIfPresent(String.self, forKey: .modeId) {
            self.modeId = modeId
        } else if let legacyMode = try c.decodeIfPresent(String.self, forKey: .mode) {
            // Migrate from old DayMode enum raw values
            self.modeId = legacyMode
        } else {
            self.modeId = DayMode.normalId
        }
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(modeId, forKey: .modeId)
        try c.encodeIfPresent(note, forKey: .note)
    }
}
