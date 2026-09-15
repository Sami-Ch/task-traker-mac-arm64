import Foundation

/// A daily usage rule for one Mac app: optional minimum (goal) and optional maximum (cap).
struct AppTimeLimit: Identifiable, Codable, Equatable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    var displayName: String
    var appPath: String
    /// 0 means no daily cap.
    var dailyLimitMinutes: Int
    /// 0 means no minute goal (see `mustOpenOnce`).
    var dailyMinMinutes: Int
    /// Any use today counts as the goal.
    var mustOpenOnce: Bool
    var isEnabled: Bool
    var order: Int
    
    init(
        bundleIdentifier: String,
        displayName: String,
        appPath: String,
        dailyLimitMinutes: Int = 0,
        dailyMinMinutes: Int = 0,
        mustOpenOnce: Bool = false,
        isEnabled: Bool = true,
        order: Int = 0
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.appPath = appPath
        self.dailyLimitMinutes = Self.clampedCap(dailyLimitMinutes)
        self.dailyMinMinutes = Self.clampedMin(dailyMinMinutes)
        self.mustOpenOnce = mustOpenOnce
        self.isEnabled = isEnabled
        self.order = order
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try c.decode(String.self, forKey: .bundleIdentifier)
        displayName = try c.decode(String.self, forKey: .displayName)
        appPath = try c.decode(String.self, forKey: .appPath)
        dailyLimitMinutes = Self.clampedCap(try c.decode(Int.self, forKey: .dailyLimitMinutes))
        dailyMinMinutes = Self.clampedMin(try c.decodeIfPresent(Int.self, forKey: .dailyMinMinutes) ?? 0)
        mustOpenOnce = try c.decodeIfPresent(Bool.self, forKey: .mustOpenOnce) ?? false
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }
    
    var dailyLimitSeconds: Int { dailyLimitMinutes * 60 }
    var hasCap: Bool { dailyLimitMinutes > 0 }
    var hasFloor: Bool { mustOpenOnce || dailyMinMinutes > 0 }
    
    var floorChoice: UsageFloorChoice {
        if mustOpenOnce { return .once }
        if dailyMinMinutes > 0 { return .minutes(dailyMinMinutes) }
        return .none
    }
    
    var capChoice: UsageCapChoice {
        hasCap ? .minutes(dailyLimitMinutes) : .none
    }
    
    static func clampedCap(_ minutes: Int) -> Int {
        if minutes <= 0 { return 0 }
        return min(max(minutes, 5), 720)
    }
    
    static func clampedMin(_ minutes: Int) -> Int {
        if minutes <= 0 { return 0 }
        return min(max(minutes, 5), 720)
    }
}

/// One calendar day's accumulated frontmost time plus which warnings already fired.
struct AppUsageDay: Codable, Equatable {
    var dateString: String
    var secondsByApp: [String: Int]
    var secondsByWebsite: [String: Int]
    var warnedApproaching: [String]
    var warnedReached: [String]
    var recentHosts: [String]
    var achievedFloors: [String]
    
    init(
        dateString: String,
        secondsByApp: [String: Int] = [:],
        secondsByWebsite: [String: Int] = [:],
        warnedApproaching: [String] = [],
        warnedReached: [String] = [],
        recentHosts: [String] = [],
        achievedFloors: [String] = []
    ) {
        self.dateString = dateString
        self.secondsByApp = secondsByApp
        self.secondsByWebsite = secondsByWebsite
        self.warnedApproaching = warnedApproaching
        self.warnedReached = warnedReached
        self.recentHosts = recentHosts
        self.achievedFloors = achievedFloors
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dateString = try c.decode(String.self, forKey: .dateString)
        secondsByApp = try c.decodeIfPresent([String: Int].self, forKey: .secondsByApp) ?? [:]
        secondsByWebsite = try c.decodeIfPresent([String: Int].self, forKey: .secondsByWebsite) ?? [:]
        warnedApproaching = try c.decodeIfPresent([String].self, forKey: .warnedApproaching) ?? []
        warnedReached = try c.decodeIfPresent([String].self, forKey: .warnedReached) ?? []
        recentHosts = try c.decodeIfPresent([String].self, forKey: .recentHosts) ?? []
        achievedFloors = try c.decodeIfPresent([String].self, forKey: .achievedFloors) ?? []
    }
    
    enum CodingKeys: String, CodingKey {
        case dateString, secondsByApp, secondsByWebsite, warnedApproaching, warnedReached, recentHosts, achievedFloors
    }
}

/// A daily usage rule for one website domain.
struct WebsiteTimeLimit: Identifiable, Codable, Equatable {
    var id: String { domain }
    let domain: String
    var dailyLimitMinutes: Int
    var dailyMinMinutes: Int
    var mustOpenOnce: Bool
    var isEnabled: Bool
    var order: Int
    
    init(
        domain: String,
        dailyLimitMinutes: Int = 0,
        dailyMinMinutes: Int = 0,
        mustOpenOnce: Bool = false,
        isEnabled: Bool = true,
        order: Int = 0
    ) {
        self.domain = domain
        self.dailyLimitMinutes = AppTimeLimit.clampedCap(dailyLimitMinutes)
        self.dailyMinMinutes = AppTimeLimit.clampedMin(dailyMinMinutes)
        self.mustOpenOnce = mustOpenOnce
        self.isEnabled = isEnabled
        self.order = order
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        domain = try c.decode(String.self, forKey: .domain)
        dailyLimitMinutes = AppTimeLimit.clampedCap(try c.decode(Int.self, forKey: .dailyLimitMinutes))
        dailyMinMinutes = AppTimeLimit.clampedMin(try c.decodeIfPresent(Int.self, forKey: .dailyMinMinutes) ?? 0)
        mustOpenOnce = try c.decodeIfPresent(Bool.self, forKey: .mustOpenOnce) ?? false
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }
    
    var dailyLimitSeconds: Int { dailyLimitMinutes * 60 }
    var hasCap: Bool { dailyLimitMinutes > 0 }
    var hasFloor: Bool { mustOpenOnce || dailyMinMinutes > 0 }
    
    var floorChoice: UsageFloorChoice {
        if mustOpenOnce { return .once }
        if dailyMinMinutes > 0 { return .minutes(dailyMinMinutes) }
        return .none
    }
    
    var capChoice: UsageCapChoice {
        hasCap ? .minutes(dailyLimitMinutes) : .none
    }
    
    func matches(host: String) -> Bool {
        let host = Self.stripWWW(host.lowercased())
        return host == domain || host.hasSuffix("." + domain)
    }
    
    /// Turns pasted URLs or hosts into a bare domain (`youtube.com`).
    static func normalizedDomain(from raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }
        text = text.replacingOccurrences(of: " ", with: "")
        if text.hasPrefix("http://") || text.hasPrefix("https://") || text.hasPrefix("//") {
            // keep as URL
        } else if text.contains("/") || text.contains("?") {
            text = "https://" + text
        } else if !text.contains("://") {
            text = "https://" + text
        }
        let host: String
        if let url = URL(string: text), let urlHost = url.host, !urlHost.isEmpty {
            host = urlHost
        } else {
            host = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .split(separator: "/").first
                .map(String.init) ?? ""
        }
        let domain = stripWWW(host)
        guard domain.contains("."), domain.contains(where: { $0.isLetter }) else { return nil }
        return domain
    }
    
    static func stripWWW(_ host: String) -> String {
        if host.hasPrefix("www.") { return String(host.dropFirst(4)) }
        return host
    }
    
    static func host(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "missing value" else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme), let host = url.host else { return nil }
        let clean = stripWWW(host.lowercased())
        return clean.isEmpty ? nil : clean
    }
}

enum UsageFloorChoice: Hashable {
    case none
    case once
    case minutes(Int)
    
    static let minuteOptions = [10, 15, 20, 30, 45, 60, 90, 120]
}

enum UsageCapChoice: Hashable {
    case none
    case minutes(Int)
    
    static let minuteOptions = [5, 10, 15, 30, 45, 60, 90, 120, 180, 240]
}

struct UsageProgress {
    let used: Int
    let maxMinutes: Int
    let minMinutes: Int
    let mustOpenOnce: Bool
    
    var hasCap: Bool { maxMinutes > 0 }
    var hasFloor: Bool { mustOpenOnce || minMinutes > 0 }
    var isOverMax: Bool { hasCap && used >= maxMinutes * 60 }
    var isMinMet: Bool {
        if mustOpenOnce { return used > 0 }
        if minMinutes > 0 { return used >= minMinutes * 60 }
        return false
    }
    
    var floorProgress: Double {
        if mustOpenOnce { return used > 0 ? 1 : 0 }
        let cap = minMinutes * 60
        guard cap > 0 else { return 0 }
        return min(1, Double(used) / Double(cap))
    }
    
    var capProgress: Double {
        let cap = maxMinutes * 60
        guard cap > 0 else { return 0 }
        return min(1, Double(used) / Double(cap))
    }
    
    var barProgress: Double {
        if hasFloor && !isMinMet { return floorProgress }
        if hasCap { return capProgress }
        if isMinMet { return 1 }
        return 0
    }
    
    var barIsOver: Bool { isOverMax }
    
    var summaryText: String {
        let usedText = mustOpenOnce && used > 0 && minMinutes == 0
            ? "Opened"
            : AppTimeFormatting.duration(seconds: used)
        var parts = [usedText]
        if mustOpenOnce && minMinutes == 0 {
            parts.append("goal: once")
        } else if minMinutes > 0 {
            parts.append("goal \(AppTimeFormatting.minutes(minMinutes))")
        }
        if maxMinutes > 0 {
            parts.append("cap \(AppTimeFormatting.minutes(maxMinutes))")
        }
        return parts.joined(separator: " · ")
    }
}

enum AppTimeFormatting {
    static func duration(seconds: Int) -> String {
        let totalMinutes = max(0, seconds) / 60
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
    
    static func minutes(_ minutes: Int) -> String {
        duration(seconds: minutes * 60)
    }
}

struct AppCandidate: Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String
}

struct UsageGoalItem: Identifiable {
    enum Kind {
        case app(AppTimeLimit)
        case website(WebsiteTimeLimit)
    }
    
    let id: String
    let kind: Kind
    let title: String
    let appPath: String?
    let progress: UsageProgress
    
    var status: GoalStatus {
        if progress.hasCap, progress.isOverMax { return .notDone }
        if progress.hasFloor {
            if progress.isMinMet { return .done }
            if progress.used > 0 { return .partial }
            return .notDone
        }
        if progress.hasCap { return .done }
        return .notDone
    }
}
