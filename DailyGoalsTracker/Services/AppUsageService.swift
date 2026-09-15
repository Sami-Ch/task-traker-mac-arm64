import AppKit
import Compression
import Foundation
import UserNotifications

/// Watches the frontmost app (and the current browser tab) against daily caps.
@Observable
final class AppUsageService {
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if isEnabled {
                Task { await requestNotificationAccess() }
                startTimer()
            } else {
                stopTimer()
                save()
            }
        }
    }
    
    var limits: [AppTimeLimit] = []
    var websiteLimits: [WebsiteTimeLimit] = []
    private(set) var todaySeconds: [String: Int] = [:]
    private(set) var todayWebsiteSeconds: [String: Int] = [:]
    private(set) var activeBundleId: String?
    private(set) var activeWebsiteDomain: String?
    private(set) var recentHosts: [String] = []
    private(set) var needsBrowserPermission = false
    /// Cap reminders stay quiet until this time (important-task snooze).
    var quietUntil: Date? = nil {
        didSet {
            if let quietUntil {
                UserDefaults.standard.set(quietUntil.timeIntervalSince1970, forKey: Keys.quietUntil)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.quietUntil)
            }
        }
    }
    
    private var usageDateString: String = ""
    private var warnedApproaching: Set<String> = []
    private var warnedReached: Set<String> = []
    private var achievedFloors: Set<String> = []
    private var timer: Timer?
    private var lastTick = Date()
    private var lastSave = Date()
    private var isDirty = false
    /// Last real app, so opening this menu-bar window does not pause YouTube/Zen time.
    private var lastRegularBundleId: String?
    private var nagSessionId: String?
    private var nagSessionStarted: Date?
    private var lastRepeatNag: Date?
    
    private let ownBundleId = Bundle.main.bundleIdentifier
    
    static let nagCategoryId = "APPTIME_CAP"
    static let snoozeActionId = "apptime.snooze15"
    private static let nagInterval: TimeInterval = 2 * 60
    static let snoozeMinutes = 15
    
    private enum Keys {
        static let enabled = "apptime.enabled"
        static let quietUntil = "apptime.quietUntil"
    }
    
    init() {
        let stored = UserDefaults.standard.object(forKey: Keys.enabled) as? Bool
        isEnabled = stored ?? true
        if let stamp = UserDefaults.standard.object(forKey: Keys.quietUntil) as? TimeInterval {
            let until = Date(timeIntervalSince1970: stamp)
            quietUntil = until > Date() ? until : nil
        }
        loadLimits()
        loadWebsiteLimits()
        loadTodayUsage()
    }
    
    func bootstrap() {
        registerNotificationCategories()
        guard isEnabled else { return }
        Task { await requestNotificationAccess() }
        startTimer()
    }
    
    func persist() {
        save()
    }
    
    private var hasAnythingToWatch: Bool {
        limits.contains { $0.isEnabled && ($0.hasFloor || $0.hasCap) }
            || websiteLimits.contains { $0.isEnabled && ($0.hasFloor || $0.hasCap) }
    }
    
    // MARK: - App limit CRUD
    
    var sortedLimits: [AppTimeLimit] {
        limits.sorted { $0.order < $1.order }
    }
    
    func hasLimit(for bundleId: String) -> Bool {
        limits.contains { $0.bundleIdentifier == bundleId }
    }
    
    func addLimit(from candidate: AppCandidate, minutes: Int = 0) {
        guard !hasLimit(for: candidate.bundleIdentifier) else { return }
        let item = AppTimeLimit(
            bundleIdentifier: candidate.bundleIdentifier,
            displayName: candidate.name,
            appPath: candidate.path,
            dailyLimitMinutes: minutes,
            order: limits.count
        )
        limits.append(item)
        saveLimits()
        requestNotificationsIfFirstCap()
        turnTrackingOn()
    }
    
    func updateLimit(_ limit: AppTimeLimit) {
        guard let index = limits.firstIndex(where: { $0.bundleIdentifier == limit.bundleIdentifier }) else { return }
        limits[index] = limit
        saveLimits()
        resetStaleFlags(id: limit.bundleIdentifier, progress: status(for: limit))
        applyUsageRules(for: limit, used: seconds(for: limit.bundleIdentifier))
        if isEnabled { startTimer() }
    }
    
    func setLimitMinutes(_ minutes: Int, for bundleId: String) {
        setCap(.minutes(minutes), for: bundleId)
    }
    
    func setFloor(_ choice: UsageFloorChoice, for bundleId: String) {
        guard var limit = limits.first(where: { $0.bundleIdentifier == bundleId }) else { return }
        applyFloor(choice, to: &limit)
        if choice != .none { limit.isEnabled = true }
        updateLimit(limit)
        if choice != .none { turnTrackingOn() }
    }
    
    func setCap(_ choice: UsageCapChoice, for bundleId: String) {
        guard var limit = limits.first(where: { $0.bundleIdentifier == bundleId }) else { return }
        applyCap(choice, to: &limit)
        if choice != .none { limit.isEnabled = true }
        updateLimit(limit)
        if choice != .none { turnTrackingOn() }
    }
    
    func setLimitEnabled(_ enabled: Bool, for bundleId: String) {
        guard var limit = limits.first(where: { $0.bundleIdentifier == bundleId }) else { return }
        guard limit.isEnabled != enabled else { return }
        limit.isEnabled = enabled
        updateLimit(limit)
        if isEnabled { startTimer() }
    }
    
    func removeLimit(_ bundleId: String) {
        limits.removeAll { $0.bundleIdentifier == bundleId }
        for i in limits.indices { limits[i].order = i }
        saveLimits()
        if isEnabled { startTimer() }
    }
    
    func seconds(for bundleId: String) -> Int {
        todaySeconds[bundleId] ?? 0
    }
    
    func status(for limit: AppTimeLimit) -> UsageProgress {
        UsageProgress(
            used: seconds(for: limit.bundleIdentifier),
            maxMinutes: limit.dailyLimitMinutes,
            minMinutes: limit.dailyMinMinutes,
            mustOpenOnce: limit.mustOpenOnce
        )
    }
    
    var overLimitApps: [AppTimeLimit] {
        sortedLimits.filter { $0.isEnabled && $0.hasCap && status(for: $0).isOverMax }
    }
    
    var usageGoals: [UsageGoalItem] {
        let apps = sortedLimits.compactMap { limit -> UsageGoalItem? in
            guard limit.isEnabled, limit.hasFloor || limit.hasCap else { return nil }
            return UsageGoalItem(
                id: limit.bundleIdentifier,
                kind: .app(limit),
                title: limit.displayName,
                appPath: limit.appPath,
                progress: status(for: limit)
            )
        }
        let sites = sortedWebsiteLimits.compactMap { limit -> UsageGoalItem? in
            guard limit.isEnabled, limit.hasFloor || limit.hasCap else { return nil }
            return UsageGoalItem(
                id: "web:\(limit.domain)",
                kind: .website(limit),
                title: limit.domain,
                appPath: nil,
                progress: status(for: limit)
            )
        }
        return apps + sites
    }
    
    var isQuiet: Bool {
        guard let quietUntil else { return false }
        return quietUntil > Date()
    }
    
    var quietRemainingSeconds: Int? {
        guard let quietUntil, quietUntil > Date() else { return nil }
        return max(0, Int(quietUntil.timeIntervalSinceNow.rounded()))
    }
    
    func snoozeReminders(minutes: Int = AppUsageService.snoozeMinutes) {
        quietUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        nagSessionStarted = Date()
        lastRepeatNag = nil
    }
    
    func endSnooze() {
        quietUntil = nil
    }
    
    /// Counts a check-in for this tracker (popover opened) or another app.
    func recordOpen(bundleId: String? = nil) {
        guard isEnabled, let id = bundleId ?? ownBundleId else { return }
        guard let limit = limits.first(where: { $0.bundleIdentifier == id && $0.isEnabled }) else { return }
        rolloverIfNeeded()
        if todaySeconds[id, default: 0] == 0 {
            todaySeconds[id] = 1
            isDirty = true
            applyUsageRules(for: limit, used: 1)
            save()
        }
    }
    
    // MARK: - Website limit CRUD
    
    var sortedWebsiteLimits: [WebsiteTimeLimit] {
        websiteLimits.sorted { $0.order < $1.order }
    }
    
    func hasWebsiteLimit(for domain: String) -> Bool {
        websiteLimits.contains { $0.domain == domain }
    }
    
    @discardableResult
    func addWebsiteLimit(domain raw: String, minutes: Int = 0) -> Bool {
        guard let domain = WebsiteTimeLimit.normalizedDomain(from: raw) else { return false }
        guard !hasWebsiteLimit(for: domain) else { return true }
        let item = WebsiteTimeLimit(domain: domain, dailyLimitMinutes: minutes, order: websiteLimits.count)
        websiteLimits.append(item)
        saveWebsiteLimits()
        requestNotificationsIfFirstCap()
        promptForBrowserAccessIfNeeded()
        turnTrackingOn()
        return true
    }
    
    func updateWebsiteLimit(_ limit: WebsiteTimeLimit) {
        guard let index = websiteLimits.firstIndex(where: { $0.domain == limit.domain }) else { return }
        websiteLimits[index] = limit
        saveWebsiteLimits()
        resetStaleFlags(id: Self.websiteWarningId(limit.domain), progress: status(for: limit))
        applyUsageRules(for: limit, used: websiteSeconds(for: limit.domain))
        if isEnabled { startTimer() }
    }
    
    func setWebsiteLimitMinutes(_ minutes: Int, for domain: String) {
        setWebsiteCap(.minutes(minutes), for: domain)
    }
    
    func setWebsiteFloor(_ choice: UsageFloorChoice, for domain: String) {
        guard var limit = websiteLimits.first(where: { $0.domain == domain }) else { return }
        applyFloor(choice, to: &limit)
        if choice != .none { limit.isEnabled = true }
        updateWebsiteLimit(limit)
        if choice != .none { turnTrackingOn() }
    }
    
    func setWebsiteCap(_ choice: UsageCapChoice, for domain: String) {
        guard var limit = websiteLimits.first(where: { $0.domain == domain }) else { return }
        applyCap(choice, to: &limit)
        if choice != .none { limit.isEnabled = true }
        updateWebsiteLimit(limit)
        if choice != .none { turnTrackingOn() }
    }
    
    func setWebsiteEnabled(_ enabled: Bool, for domain: String) {
        guard var limit = websiteLimits.first(where: { $0.domain == domain }) else { return }
        guard limit.isEnabled != enabled else { return }
        limit.isEnabled = enabled
        updateWebsiteLimit(limit)
        if isEnabled { startTimer() }
    }
    
    func removeWebsiteLimit(_ domain: String) {
        websiteLimits.removeAll { $0.domain == domain }
        for i in websiteLimits.indices { websiteLimits[i].order = i }
        saveWebsiteLimits()
        if isEnabled { startTimer() }
    }
    
    func websiteSeconds(for domain: String) -> Int {
        todayWebsiteSeconds[domain] ?? 0
    }
    
    func status(for limit: WebsiteTimeLimit) -> UsageProgress {
        UsageProgress(
            used: websiteSeconds(for: limit.domain),
            maxMinutes: limit.dailyLimitMinutes,
            minMinutes: limit.dailyMinMinutes,
            mustOpenOnce: limit.mustOpenOnce
        )
    }
    
    var overLimitWebsites: [WebsiteTimeLimit] {
        sortedWebsiteLimits.filter { $0.isEnabled && $0.hasCap && status(for: $0).isOverMax }
    }
    
    var suggestedWebsiteHosts: [String] {
        recentHosts.filter { !hasWebsiteLimit(for: $0) }
    }
    
    // MARK: - Tracking
    
    private func startTimer() {
        timer?.invalidate()
        timer = nil
        guard isEnabled, hasAnythingToWatch else { return }
        lastTick = Date()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        activeBundleId = nil
        activeWebsiteDomain = nil
    }
    
    private func turnTrackingOn() {
        if !isEnabled {
            isEnabled = true
        } else {
            startTimer()
        }
    }
    
    private func trackedFrontmostApp() -> NSRunningApplication? {
        let running = NSWorkspace.shared.runningApplications
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != ownBundleId,
           front.activationPolicy == .regular {
            lastRegularBundleId = front.bundleIdentifier
            return front
        }
        if let id = lastRegularBundleId,
           let app = running.first(where: { $0.bundleIdentifier == id && !$0.isTerminated }) {
            return app
        }
        return running.first {
            $0.isActive && $0.activationPolicy == .regular && $0.bundleIdentifier != ownBundleId
        }
    }
    
    private func tick() {
        rolloverIfNeeded()
        
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        guard elapsed > 0 else { return }
        guard !isScreenLocked else {
            activeBundleId = nil
            activeWebsiteDomain = nil
            lastRegularBundleId = nil
            return
        }
        
        guard let app = trackedFrontmostApp(),
              let bundleId = app.bundleIdentifier
        else {
            activeBundleId = nil
            activeWebsiteDomain = nil
            return
        }
        
        // Ignore long gaps (sleep). Still identify the current tab so Zen updates after a pause.
        let added = elapsed < 8 ? max(1, Int(elapsed.rounded())) : 0
        
        if let limit = limits.first(where: { $0.bundleIdentifier == bundleId && $0.isEnabled }) {
            activeBundleId = bundleId
            if added > 0 {
                todaySeconds[bundleId, default: 0] += added
                isDirty = true
                applyUsageRules(for: limit, used: todaySeconds[bundleId] ?? 0)
            }
        } else {
            activeBundleId = nil
        }
        
        activeWebsiteDomain = nil
        if websiteLimits.contains(where: { $0.isEnabled && ($0.hasFloor || $0.hasCap) }),
           BrowserURLReader.supports(bundleId) {
            var denied = false
            if let host = BrowserURLReader.currentHost(for: bundleId, permissionDenied: &denied) {
                needsBrowserPermission = false
                rememberHost(host)
                if let site = websiteLimits.first(where: { $0.isEnabled && $0.matches(host: host) }) {
                    activeWebsiteDomain = site.domain
                    if added > 0 {
                        todayWebsiteSeconds[site.domain, default: 0] += added
                        isDirty = true
                        applyUsageRules(for: site, used: todayWebsiteSeconds[site.domain] ?? 0)
                    }
                }
            } else if denied {
                needsBrowserPermission = true
            }
        }
        
        if now.timeIntervalSince(lastSave) >= 10 {
            save()
        }
        
        evaluateRepeatingNags()
    }
    
    private func rememberHost(_ host: String) {
        recentHosts.removeAll { $0 == host }
        recentHosts.insert(host, at: 0)
        if recentHosts.count > 24 {
            recentHosts = Array(recentHosts.prefix(24))
        }
    }
    
    private func capStatus(used: Int, cap: Int) -> (used: Int, remaining: Int, progress: Double, isOver: Bool) {
        let remaining = max(0, cap - used)
        let progress = cap > 0 ? min(1, Double(used) / Double(cap)) : 0
        return (used, remaining, progress, cap > 0 && used >= cap)
    }
    
    private static func websiteWarningId(_ domain: String) -> String {
        "web:\(domain)"
    }
    
    private func applyFloor(_ choice: UsageFloorChoice, to limit: inout AppTimeLimit) {
        switch choice {
        case .none:
            limit.mustOpenOnce = false
            limit.dailyMinMinutes = 0
        case .once:
            limit.mustOpenOnce = true
            limit.dailyMinMinutes = 0
        case .minutes(let minutes):
            limit.mustOpenOnce = false
            limit.dailyMinMinutes = AppTimeLimit.clampedMin(minutes)
        }
    }
    
    private func applyFloor(_ choice: UsageFloorChoice, to limit: inout WebsiteTimeLimit) {
        switch choice {
        case .none:
            limit.mustOpenOnce = false
            limit.dailyMinMinutes = 0
        case .once:
            limit.mustOpenOnce = true
            limit.dailyMinMinutes = 0
        case .minutes(let minutes):
            limit.mustOpenOnce = false
            limit.dailyMinMinutes = AppTimeLimit.clampedMin(minutes)
        }
    }
    
    private func applyCap(_ choice: UsageCapChoice, to limit: inout AppTimeLimit) {
        switch choice {
        case .none: limit.dailyLimitMinutes = 0
        case .minutes(let minutes): limit.dailyLimitMinutes = AppTimeLimit.clampedCap(minutes)
        }
    }
    
    private func applyCap(_ choice: UsageCapChoice, to limit: inout WebsiteTimeLimit) {
        switch choice {
        case .none: limit.dailyLimitMinutes = 0
        case .minutes(let minutes): limit.dailyLimitMinutes = AppTimeLimit.clampedCap(minutes)
        }
    }
    
    private func applyUsageRules(for limit: AppTimeLimit, used: Int) {
        let progress = UsageProgress(
            used: used,
            maxMinutes: limit.dailyLimitMinutes,
            minMinutes: limit.dailyMinMinutes,
            mustOpenOnce: limit.mustOpenOnce
        )
        if limit.hasCap {
            evaluateWarnings(
                id: limit.bundleIdentifier,
                used: used,
                cap: limit.dailyLimitSeconds,
                name: limit.displayName,
                minutes: limit.dailyLimitMinutes
            )
        }
        evaluateFloor(id: limit.bundleIdentifier, name: limit.displayName, progress: progress)
    }
    
    private func applyUsageRules(for limit: WebsiteTimeLimit, used: Int) {
        let progress = UsageProgress(
            used: used,
            maxMinutes: limit.dailyLimitMinutes,
            minMinutes: limit.dailyMinMinutes,
            mustOpenOnce: limit.mustOpenOnce
        )
        let id = Self.websiteWarningId(limit.domain)
        if limit.hasCap {
            evaluateWarnings(
                id: id,
                used: used,
                cap: limit.dailyLimitSeconds,
                name: limit.domain,
                minutes: limit.dailyLimitMinutes
            )
        }
        evaluateFloor(id: id, name: limit.domain, progress: progress)
    }
    
    private func resetStaleFlags(id: String, progress: UsageProgress) {
        if !progress.hasCap || !progress.isOverMax {
            warnedReached.remove(id)
        }
        if !progress.hasCap || progress.used < max(0, progress.maxMinutes * 60 - 5 * 60) {
            warnedApproaching.remove(id)
        }
        if !progress.isMinMet {
            achievedFloors.remove(id)
        }
    }
    
    private func evaluateWarnings(id: String, used: Int, cap: Int, name: String, minutes: Int) {
        guard cap > 0, !isQuiet else { return }
        if used >= cap {
            guard !warnedReached.contains(id) else { return }
            warnedReached.insert(id)
            warnedApproaching.insert(id)
            isDirty = true
            notifyReached(name: name, used: used, minutes: minutes, id: id)
            nagSessionId = id
            nagSessionStarted = Date()
            return
        }
        
        let warningWindow = 5 * 60
        if cap > warningWindow, used >= cap - warningWindow, !warnedApproaching.contains(id) {
            warnedApproaching.insert(id)
            isDirty = true
            notifyApproaching(name: name, remaining: cap - used, minutes: minutes, id: id)
        }
    }
    
    private func activeOverCapTarget() -> (id: String, name: String, used: Int, minutes: Int)? {
        if let domain = activeWebsiteDomain,
           let site = websiteLimits.first(where: { $0.domain == domain && $0.isEnabled && $0.hasCap }),
           status(for: site).isOverMax {
            return (Self.websiteWarningId(domain), site.domain, websiteSeconds(for: domain), site.dailyLimitMinutes)
        }
        if let bundleId = activeBundleId,
           let app = limits.first(where: { $0.bundleIdentifier == bundleId && $0.isEnabled && $0.hasCap }),
           status(for: app).isOverMax {
            return (bundleId, app.displayName, seconds(for: bundleId), app.dailyLimitMinutes)
        }
        return nil
    }
    
    private func evaluateRepeatingNags() {
        clearExpiredSnooze()
        guard let target = activeOverCapTarget() else {
            nagSessionId = nil
            nagSessionStarted = nil
            return
        }
        guard !isQuiet else { return }
        
        let now = Date()
        if nagSessionId != target.id {
            nagSessionId = target.id
            nagSessionStarted = now
            return
        }
        guard let started = nagSessionStarted else { return }
        let waited = now.timeIntervalSince(started)
        let sinceLast = lastRepeatNag.map { now.timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        guard waited >= Self.nagInterval, sinceLast >= Self.nagInterval else { return }
        
        lastRepeatNag = now
        notifyStillOver(name: target.name, used: target.used, minutes: target.minutes, id: target.id)
    }
    
    private func clearExpiredSnooze() {
        if let quietUntil, quietUntil <= Date() {
            self.quietUntil = nil
        }
    }
    
    private func evaluateFloor(id: String, name: String, progress: UsageProgress) {
        guard progress.hasFloor, progress.isMinMet, !achievedFloors.contains(id) else { return }
        achievedFloors.insert(id)
        isDirty = true
        let goal: String
        if progress.mustOpenOnce && progress.minMinutes == 0 {
            goal = "opened today"
        } else {
            goal = AppTimeFormatting.minutes(progress.minMinutes)
        }
        deliver(
            id: "apptime.goal.\(id).\(todayKey())",
            title: "Goal met: \(name)",
            body: "You hit today's \(goal) goal."
        )
    }
    
    private func requestNotificationsIfFirstCap() {
        if limits.count + websiteLimits.count == 1 {
            Task { await requestNotificationAccess() }
        }
    }
    
    private func promptForBrowserAccessIfNeeded() {
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        guard let id = running.first(where: { BrowserURLReader.supports($0) }) else { return }
        var denied = false
        _ = BrowserURLReader.currentHost(for: id, permissionDenied: &denied)
        if denied { needsBrowserPermission = true }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationAccess() async {
        let center = UNUserNotificationCenter.current()
        registerNotificationCategories()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        default:
            break
        }
    }
    
    func registerNotificationCategories() {
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionId,
            title: "Do Not Disturb \(Self.snoozeMinutes) min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.nagCategoryId,
            actions: [snooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    private func notifyApproaching(name: String, remaining: Int, minutes: Int, id: String) {
        deliver(
            id: "apptime.soon.\(id).\(todayKey())",
            title: "\(name): \(AppTimeFormatting.duration(seconds: remaining)) left",
            body: "You're close to today's \(AppTimeFormatting.minutes(minutes)) limit.",
            nag: true
        )
    }
    
    private func notifyReached(name: String, used: Int, minutes: Int, id: String) {
        deliver(
            id: "apptime.up.\(id).\(todayKey())",
            title: "Time's up for \(name)",
            body: "You've used \(AppTimeFormatting.duration(seconds: used)) today. Limit is \(AppTimeFormatting.minutes(minutes)). Time to stop.",
            nag: true
        )
    }
    
    private func notifyStillOver(name: String, used: Int, minutes: Int, id: String) {
        deliver(
            id: "apptime.still.\(id).\(Int(Date().timeIntervalSince1970))",
            title: "Still on \(name)",
            body: "That's \(AppTimeFormatting.duration(seconds: used)) today — over the \(AppTimeFormatting.minutes(minutes)) cap. Switch away, or Do Not Disturb for \(Self.snoozeMinutes) min.",
            nag: true
        )
    }
    
    private func deliver(id: String, title: String, body: String, nag: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if nag {
            content.categoryIdentifier = Self.nagCategoryId
        }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - System state
    
    private var isScreenLocked: Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return dict["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
    
    // MARK: - Persistence
    
    private var supportURL: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appURL = urls[0].appendingPathComponent("DailyGoalsTracker", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appURL.path) {
            try? FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
        }
        return appURL
    }
    
    private var limitsURL: URL { supportURL.appendingPathComponent("app_time_limits.json") }
    private var websiteLimitsURL: URL { supportURL.appendingPathComponent("website_time_limits.json") }
    private var usageURL: URL { supportURL.appendingPathComponent("app_time_usage.json") }
    
    private func todayKey() -> String {
        GoalEntry.dateString(from: Date())
    }
    
    private func rolloverIfNeeded() {
        let key = todayKey()
        guard key != usageDateString else { return }
        usageDateString = key
        todaySeconds = [:]
        todayWebsiteSeconds = [:]
        warnedApproaching = []
        warnedReached = []
        achievedFloors = []
        nagSessionId = nil
        nagSessionStarted = nil
        lastRepeatNag = nil
        isDirty = true
        save()
    }
    
    private func loadLimits() {
        guard let data = try? Data(contentsOf: limitsURL),
              let decoded = try? JSONDecoder().decode([AppTimeLimit].self, from: data) else {
            return
        }
        limits = decoded.sorted { $0.order < $1.order }
    }
    
    private func loadWebsiteLimits() {
        guard let data = try? Data(contentsOf: websiteLimitsURL),
              let decoded = try? JSONDecoder().decode([WebsiteTimeLimit].self, from: data) else {
            return
        }
        websiteLimits = decoded.sorted { $0.order < $1.order }
    }
    
    private func loadTodayUsage() {
        usageDateString = todayKey()
        guard let snapshot = loadUsageFile(), snapshot.dateString == usageDateString else { return }
        todaySeconds = snapshot.secondsByApp
        todayWebsiteSeconds = snapshot.secondsByWebsite
        warnedApproaching = Set(snapshot.warnedApproaching)
        warnedReached = Set(snapshot.warnedReached)
        recentHosts = snapshot.recentHosts
        achievedFloors = Set(snapshot.achievedFloors)
    }
    
    private func loadUsageFile() -> AppUsageDay? {
        guard let data = try? Data(contentsOf: usageURL) else { return nil }
        return try? JSONDecoder().decode(AppUsageDay.self, from: data)
    }
    
    private func saveLimits() {
        guard let data = try? JSONEncoder().encode(limits) else { return }
        try? data.write(to: limitsURL)
    }
    
    private func saveWebsiteLimits() {
        guard let data = try? JSONEncoder().encode(websiteLimits) else { return }
        try? data.write(to: websiteLimitsURL)
    }
    
    private func save() {
        let snapshot = AppUsageDay(
            dateString: todayKey(),
            secondsByApp: todaySeconds,
            secondsByWebsite: todayWebsiteSeconds,
            warnedApproaching: Array(warnedApproaching),
            warnedReached: Array(warnedReached),
            recentHosts: recentHosts,
            achievedFloors: Array(achievedFloors)
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: usageURL)
        }
        lastSave = Date()
        isDirty = false
    }
}

extension AppUsageService {
    /// Installed + currently running regular apps the user can cap, excluding this tracker.
    func availableApps() -> [AppCandidate] {
        var seen = Set<String>()
        var result: [AppCandidate] = []
        
        if let id = ownBundleId {
            let name = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Daily Goals Tracker"
            seen.insert(id)
            result.append(AppCandidate(bundleIdentifier: id, name: name, path: Bundle.main.bundlePath))
        }
        
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
        for app in running {
            guard let id = app.bundleIdentifier, !seen.contains(id) else { continue }
            let path = app.bundleURL?.path ?? ""
            let name = app.localizedName ?? id
            seen.insert(id)
            result.append(AppCandidate(bundleIdentifier: id, name: name, path: path))
        }
        
        let directories = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        for directory in directories {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in contents where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let id = bundle.bundleIdentifier,
                      !seen.contains(id) else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                seen.insert(id)
                result.append(AppCandidate(bundleIdentifier: id, name: name, path: url.path))
            }
        }
        
        return result.sorted { lhs, rhs in
            if lhs.bundleIdentifier == ownBundleId { return true }
            if rhs.bundleIdentifier == ownBundleId { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

// MARK: - Current tab URL

private enum BrowserURLReader {
    static func supports(_ bundleId: String) -> Bool {
        geckoSupportFolder(for: bundleId) != nil || scriptAppName(for: bundleId) != nil
    }
    
    static func currentHost(for bundleId: String, permissionDenied: inout Bool) -> String? {
        if let folder = geckoSupportFolder(for: bundleId) {
            return MozillaSessionStore.currentHost(supportFolderName: folder)
        }
        guard let appName = scriptAppName(for: bundleId) else { return nil }
        let source: String
        if bundleId.hasPrefix("com.apple.Safari") {
            source = """
            tell application id "\(bundleId)"
                try
                    return URL of current tab of front window
                on error
                    return ""
                end try
            end tell
            """
        } else {
            source = """
            tell application "\(appName)"
                try
                    return URL of active tab of front window
                on error
                    return ""
                end try
            end tell
            """
        }
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if let error {
            let number = error["NSAppleScriptErrorNumber"] as? Int
            if number == -1743 || number == -10004 {
                permissionDenied = true
            }
            return nil
        }
        return WebsiteTimeLimit.host(from: result.stringValue ?? "")
    }
    
    private static func geckoSupportFolder(for bundleId: String) -> String? {
        switch bundleId {
        case "app.zen-browser.zen", "app.zen-browser.zen-twilight":
            return "zen"
        case "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.firefox.nightly":
            return "Firefox"
        default:
            return bundleId.hasPrefix("app.zen-browser") ? "zen" : nil
        }
    }
    
    private static func scriptAppName(for bundleId: String) -> String? {
        switch bundleId {
        case "com.apple.Safari": return "Safari"
        case "com.apple.SafariTechnologyPreview": return "Safari Technology Preview"
        case "com.google.Chrome": return "Google Chrome"
        case "com.brave.Browser": return "Brave Browser"
        case "com.microsoft.edgemac": return "Microsoft Edge"
        case "company.thebrowser.Browser": return "Arc"
        case "com.vivaldi.Vivaldi": return "Vivaldi"
        case "org.chromium.Chromium": return "Chromium"
        default: return nil
        }
    }
}

/// Zen/Firefox don't expose the current tab to AppleScript. The selected URL is in recovery.jsonlz4.
private enum MozillaSessionStore {
    private static var cache: (path: String, mtime: Date, host: String?)?
    
    static func currentHost(supportFolderName: String) -> String? {
        let support = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(supportFolderName)", isDirectory: true)
        guard let file = newestRecoveryFile(in: support) else { return nil }
        let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        if let cache, cache.path == file.path, cache.mtime == mtime {
            return cache.host
        }
        let host = decodeHost(from: file)
        cache = (file.path, mtime, host)
        return host
    }
    
    private static func newestRecoveryFile(in support: URL) -> URL? {
        let candidates = profileDirectories(in: support).compactMap { profile -> URL? in
            let file = profile.appendingPathComponent("sessionstore-backups/recovery.jsonlz4")
            return FileManager.default.fileExists(atPath: file.path) ? file : nil
        }
        return candidates.max { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left < right
        }
    }
    
    private static func profileDirectories(in support: URL) -> [URL] {
        let ini = support.appendingPathComponent("profiles.ini")
        guard let text = try? String(contentsOf: ini, encoding: .utf8) else { return [] }
        var paths: [URL] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let raw = line.trimmingCharacters(in: .whitespaces)
            let lower = raw.lowercased()
            guard lower.hasPrefix("path=") else { continue }
            let path = String(raw.dropFirst(5))
            if path.hasPrefix("/") {
                paths.append(URL(fileURLWithPath: path))
            } else {
                paths.append(support.appendingPathComponent(path))
            }
        }
        return paths
    }
    
    private static func decodeHost(from file: URL) -> String? {
        guard let data = try? Data(contentsOf: file),
              let json = decompressMozLZ4(data),
              let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let windows = root["windows"] as? [[String: Any]],
              !windows.isEmpty
        else { return nil }
        
        let selectedIndex = ((root["selectedWindow"] as? Int) ?? 1) - 1
        let window = windows.indices.contains(selectedIndex) ? windows[selectedIndex] : windows[0]
        guard let tabs = window["tabs"] as? [[String: Any]], !tabs.isEmpty else { return nil }
        let tabIndex = ((window["selected"] as? Int) ?? 1) - 1
        let tab = tabs.indices.contains(tabIndex) ? tabs[tabIndex] : tabs[0]
        guard let entries = tab["entries"] as? [[String: Any]], !entries.isEmpty else { return nil }
        let entryIndex = ((tab["index"] as? Int) ?? entries.count) - 1
        let entry = entries.indices.contains(entryIndex) ? entries[entryIndex] : entries.last
        return WebsiteTimeLimit.host(from: entry?["url"] as? String ?? "")
    }
    
    private static func decompressMozLZ4(_ data: Data) -> Data? {
        let magic = Data("mozLz40\0".utf8)
        guard data.count > 12, data.prefix(8) == magic else { return nil }
        let uncompressedSize = Int(data.subdata(in: 8..<12).withUnsafeBytes { raw in
            UInt32(littleEndian: raw.loadUnaligned(as: UInt32.self))
        })
        guard uncompressedSize > 0, uncompressedSize < 20_000_000 else { return nil }
        var output = Data(count: uncompressedSize)
        let decoded = output.withUnsafeMutableBytes { dest in
            data.subdata(in: 12..<data.count).withUnsafeBytes { source in
                compression_decode_buffer(
                    dest.bindMemory(to: UInt8.self).baseAddress!,
                    uncompressedSize,
                    source.bindMemory(to: UInt8.self).baseAddress!,
                    data.count - 12,
                    nil,
                    COMPRESSION_LZ4_RAW
                )
            }
        }
        guard decoded > 0 else { return nil }
        if decoded < output.count {
            output.count = decoded
        }
        return output
    }
}
