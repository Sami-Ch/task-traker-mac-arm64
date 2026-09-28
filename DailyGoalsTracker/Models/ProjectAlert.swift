import Foundation
import UserNotifications

// MARK: - Schedule

enum ProjectAlertSchedule: Codable, Equatable, Hashable {
    /// Every hour at the given minute (0–59).
    case hourly(minute: Int)
    /// Every day at HH:mm.
    case daily(hour: Int, minute: Int)
    /// One-shot alerts on the given civil days at HH:mm.
    case specificDates(dates: [Date], hour: Int, minute: Int)
    /// Once at `targetDate - offsetSeconds`.
    case beforeDeadline(offsetSeconds: TimeInterval)
    /// Daily at HH:mm until the project deadline.
    case dailyUntilDeadline(hour: Int, minute: Int)
    /// Once at `startDate - offsetSeconds` (upcoming projects).
    case beforeStart(offsetSeconds: TimeInterval)
    /// Once on the project start day at HH:mm.
    case onStartDay(hour: Int, minute: Int)
    
    var kindTitle: String {
        switch self {
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .specificDates: return "Specific dates"
        case .beforeDeadline: return "Before deadline"
        case .dailyUntilDeadline: return "Daily until deadline"
        case .beforeStart: return "Before start"
        case .onStartDay: return "On start day"
        }
    }
    
    var summary: String {
        switch self {
        case .hourly(let minute):
            return String(format: "Every hour at :%02d", minute)
        case .daily(let hour, let minute):
            return "Daily at \(Self.formatTime(hour: hour, minute: minute))"
        case .specificDates(let dates, let hour, let minute):
            let time = Self.formatTime(hour: hour, minute: minute)
            if dates.isEmpty { return "Specific dates at \(time)" }
            if dates.count == 1 {
                return "\(Self.formatDay(dates[0])) at \(time)"
            }
            return "\(dates.count) dates at \(time)"
        case .beforeDeadline(let offset):
            return "\(Self.formatOffset(offset)) before deadline"
        case .dailyUntilDeadline(let hour, let minute):
            return "Daily at \(Self.formatTime(hour: hour, minute: minute)) until deadline"
        case .beforeStart(let offset):
            return "\(Self.formatOffset(offset)) before start"
        case .onStartDay(let hour, let minute):
            return "On start day at \(Self.formatTime(hour: hour, minute: minute))"
        }
    }
    
    private static func formatTime(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let cal = Calendar.current
        let date = cal.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    private static func formatDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
    
    private static func formatOffset(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        if hours >= 24 && hours % 24 == 0 {
            let days = hours / 24
            return days == 1 ? "1 day" : "\(days) days"
        }
        if hours >= 1 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        let minutes = max(1, Int(seconds) / 60)
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

// MARK: - Sound catalog

enum ProjectAlertSound: String, CaseIterable, Identifiable, Codable {
    case `default` = "default"
    case none = "none"
    case alert = "alert"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .default: return "Default"
        case .none: return "Silent"
        case .alert: return "Alert"
        }
    }
    
    /// Resolves a UNNotificationSound. Bundled files must be in the app bundle root or Sounds/.
    func notificationSound() -> UNNotificationSound? {
        switch self {
        case .default:
            return .default
        case .none:
            return nil
        case .alert:
            if Bundle.main.url(forResource: "alert", withExtension: "aiff") != nil {
                return UNNotificationSound(named: UNNotificationSoundName("alert.aiff"))
            }
            if Bundle.main.url(forResource: "alert", withExtension: "aiff", subdirectory: "Sounds") != nil {
                return UNNotificationSound(named: UNNotificationSoundName("Sounds/alert.aiff"))
            }
            if Bundle.main.url(forResource: "alert", withExtension: "caf") != nil {
                return UNNotificationSound(named: UNNotificationSoundName("alert.caf"))
            }
            return .default
        }
    }
    
    static func from(soundName: String) -> ProjectAlertSound {
        ProjectAlertSound(rawValue: soundName) ?? .default
    }
}

// MARK: - Alert

struct ProjectAlert: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    /// Optional display override; empty means use project/milestone title.
    var title: String
    var isEnabled: Bool
    var schedule: ProjectAlertSchedule
    /// `ProjectAlertSound.rawValue`
    var soundName: String
    var snoozeMinutesDefault: Int
    /// `nil` = project-level; otherwise scoped to that milestone.
    var milestoneId: UUID?
    
    init(
        id: UUID = UUID(),
        title: String = "",
        isEnabled: Bool = true,
        schedule: ProjectAlertSchedule = .daily(hour: 9, minute: 0),
        soundName: String = ProjectAlertSound.default.rawValue,
        snoozeMinutesDefault: Int = 15,
        milestoneId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.schedule = schedule
        self.soundName = soundName
        self.snoozeMinutesDefault = snoozeMinutesDefault
        self.milestoneId = milestoneId
    }
    
    var sound: ProjectAlertSound {
        ProjectAlertSound.from(soundName: soundName)
    }
    
    var isProjectScoped: Bool { milestoneId == nil }
    
    func displayTitle(project: Project) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        if let mid = milestoneId,
           let milestone = project.milestones.first(where: { $0.id == mid }) {
            return milestone.title
        }
        return project.title
    }
}

// MARK: - Deadline offset presets

enum ProjectAlertDeadlineOffset: CaseIterable, Identifiable {
    case oneHour
    case oneDay
    case oneWeek
    case custom
    
    var id: String {
        switch self {
        case .oneHour: return "1h"
        case .oneDay: return "1d"
        case .oneWeek: return "1w"
        case .custom: return "custom"
        }
    }
    
    var title: String {
        switch self {
        case .oneHour: return "1 hour"
        case .oneDay: return "1 day"
        case .oneWeek: return "1 week"
        case .custom: return "Custom"
        }
    }
    
    var seconds: TimeInterval? {
        switch self {
        case .oneHour: return 3600
        case .oneDay: return 86400
        case .oneWeek: return 604800
        case .custom: return nil
        }
    }
    
    static func matching(_ seconds: TimeInterval) -> ProjectAlertDeadlineOffset {
        for preset in allCases {
            if let s = preset.seconds, abs(s - seconds) < 1 { return preset }
        }
        return .custom
    }
}
