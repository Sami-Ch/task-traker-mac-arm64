import Foundation
import UserNotifications

/// Schedules and manages local notifications for project / milestone alerts.
@Observable
final class ProjectAlertService {
    static let categoryId = "project.alert"
    static let snooze15Id = "project.alert.snooze15"
    static let snooze30Id = "project.alert.snooze30"
    static let snooze60Id = "project.alert.snooze60"
    static let idPrefix = "project.alert."
    
    private weak var dataStore: DataStore?
    
    func attach(dataStore: DataStore) {
        self.dataStore = dataStore
    }
    
    func bootstrap() {
        Task { @MainActor in
            await requestAuthorization()
            registerCategories()
            if let dataStore {
                resyncAll(projects: dataStore.projects)
            }
        }
    }
    
    // MARK: - Auth / categories
    
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        default:
            break
        }
    }
    
    func registerCategories() {
        let snooze15 = UNNotificationAction(
            identifier: Self.snooze15Id,
            title: "Snooze 15 min",
            options: []
        )
        let snooze30 = UNNotificationAction(
            identifier: Self.snooze30Id,
            title: "Snooze 30 min",
            options: []
        )
        let snooze60 = UNNotificationAction(
            identifier: Self.snooze60Id,
            title: "Snooze 1 hour",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryId,
            actions: [snooze15, snooze30, snooze60],
            intentIdentifiers: [],
            options: []
        )
        
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { existing in
            var merged = existing
            merged.insert(category)
            // Keep app-time category if present
            center.setNotificationCategories(merged)
        }
    }
    
    // MARK: - Resync
    
    func resyncAll(projects: [Project]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { [weak self] requests in
            let stale = requests.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            
            guard let self else { return }
            for project in projects {
                self.schedule(project: project)
            }
        }
    }
    
    private func schedule(project: Project) {
        guard project.isActive || project.isPaused || project.isUpcoming else { return }
        guard !project.isCompleted && !project.isArchived else { return }
        
        for alert in project.alerts where alert.isEnabled {
            if let milestoneId = alert.milestoneId {
                guard let milestone = project.milestones.first(where: { $0.id == milestoneId }),
                      !milestone.isCompleted else { continue }
            }
            scheduleAlert(alert, for: project)
        }
    }
    
    private func scheduleAlert(_ alert: ProjectAlert, for project: Project) {
        let center = UNUserNotificationCenter.current()
        let content = makeContent(alert: alert, project: project)
        
        switch alert.schedule {
        case .hourly(let minute):
            var comps = DateComponents()
            comps.minute = min(59, max(0, minute))
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            add(center: center, id: requestId(project: project.id, alert: alert.id, key: "hourly"), content: content, trigger: trigger)
            
        case .daily(let hour, let minute):
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            add(center: center, id: requestId(project: project.id, alert: alert.id, key: "daily"), content: content, trigger: trigger)
            
        case .specificDates(let dates, let hour, let minute):
            let cal = Calendar.current
            let now = Date()
            for date in dates {
                var comps = cal.dateComponents([.year, .month, .day], from: date)
                comps.hour = hour
                comps.minute = minute
                guard let fire = cal.date(from: comps), fire > now else { continue }
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let key = GoalEntry.dateString(from: date)
                add(center: center, id: requestId(project: project.id, alert: alert.id, key: key), content: content, trigger: trigger)
            }
            
        case .beforeDeadline(let offset):
            guard let target = project.targetDate else { return }
            let fire = target.addingTimeInterval(-offset)
            guard fire > Date() else { return }
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fire
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            add(center: center, id: requestId(project: project.id, alert: alert.id, key: "before"), content: content, trigger: trigger)
            
        case .dailyUntilDeadline(let hour, let minute):
            guard let target = project.targetDate else { return }
            let today = GoalEntry.startOfCivilDay(for: Date())
            let deadlineDay = GoalEntry.startOfCivilDay(for: target)
            guard today <= deadlineDay else { return }
            
            // Schedule individual days up to deadline (macOS has pending request limits; cap horizon).
            let cal = Calendar.current
            var day = today
            var index = 0
            while day <= deadlineDay && index < 60 {
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = hour
                comps.minute = minute
                if let fire = cal.date(from: comps), fire > Date() {
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let key = "until.\(GoalEntry.dateString(from: day))"
                    add(center: center, id: requestId(project: project.id, alert: alert.id, key: key), content: content, trigger: trigger)
                }
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                index += 1
            }
            
        case .beforeStart(let offset):
            let fire = project.startDate.addingTimeInterval(-offset)
            guard fire > Date() else { return }
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fire
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            add(center: center, id: requestId(project: project.id, alert: alert.id, key: "beforeStart"), content: content, trigger: trigger)
            
        case .onStartDay(let hour, let minute):
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: project.startDate)
            comps.hour = hour
            comps.minute = minute
            guard let fire = cal.date(from: comps), fire > Date() else { return }
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            add(center: center, id: requestId(project: project.id, alert: alert.id, key: "onStart"), content: content, trigger: trigger)
        }
    }
    
    private func makeContent(alert: ProjectAlert, project: Project) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let name = alert.displayTitle(project: project)
        content.title = name
        if let mid = alert.milestoneId,
           let milestone = project.milestones.first(where: { $0.id == mid }) {
            content.body = "\(project.title) · \(milestone.title) — \(alert.schedule.summary)"
        } else {
            content.body = "\(project.title) — \(alert.schedule.summary)"
        }
        content.sound = alert.sound.notificationSound()
        content.categoryIdentifier = Self.categoryId
        content.userInfo = [
            "projectId": project.id.uuidString,
            "alertId": alert.id.uuidString,
            "soundName": alert.soundName
        ]
        return content
    }
    
    private func requestId(project: UUID, alert: UUID, key: String) -> String {
        "\(Self.idPrefix)\(project.uuidString).\(alert.uuidString).\(key)"
    }
    
    private func add(
        center: UNUserNotificationCenter,
        id: String,
        content: UNMutableNotificationContent,
        trigger: UNNotificationTrigger
    ) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
    
    // MARK: - Snooze
    
    static func snoozeMinutes(for actionId: String) -> Int? {
        switch actionId {
        case snooze15Id: return 15
        case snooze30Id: return 30
        case snooze60Id: return 60
        default: return nil
        }
    }
    
    func handleSnooze(response: UNNotificationResponse) {
        guard let minutes = Self.snoozeMinutes(for: response.actionIdentifier) else { return }
        let original = response.notification.request.content
        let content = UNMutableNotificationContent()
        content.title = original.title
        content.body = "Snoozed reminder — \(original.body)"
        content.categoryIdentifier = Self.categoryId
        content.userInfo = original.userInfo
        
        let soundName = (original.userInfo["soundName"] as? String) ?? ProjectAlertSound.default.rawValue
        content.sound = ProjectAlertSound.from(soundName: soundName).notificationSound()
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )
        let id = "\(Self.idPrefix)snooze.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
