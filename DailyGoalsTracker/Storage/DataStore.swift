import Foundation
import SwiftUI

/// Observable data store managing goals and entries with JSON persistence
@Observable
final class DataStore {
    // MARK: - Published Data
    var goals: [Goal] = []
    var entries: [String: GoalEntry] = [:]  // Key: "goalId_date"
    var planningGoals: [PlanningGoal] = []  // Big picture goals
    var dayRecords: [String: DayRecord] = [:]  // Key: date string
    var dayModes: [DayMode] = []
    var journals: [String: JournalEntry] = [:]  // Key: date string
    var snapshots: [String: DaySnapshot] = [:]  // Key: date string
    var settings: TrackerSettings = .default
    
    /// Used for Maghrib-based day start. Set from AppDelegate.
    weak var prayerService: PrayerService?
    
    var calendarPresentation: CalendarPresentation {
        CalendarPresentation(mode: settings.calendarDisplay)
    }
    
    // MARK: - File Paths
    private let fileManager = FileManager.default
    private var appSupportURL: URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appURL = urls[0].appendingPathComponent("DailyGoalsTracker", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appURL.path) {
            try? fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
        }
        return appURL
    }
    
    private var goalsFileURL: URL {
        appSupportURL.appendingPathComponent("goals.json")
    }
    
    private var entriesFileURL: URL {
        appSupportURL.appendingPathComponent("entries.json")
    }
    
    private var planningGoalsFileURL: URL {
        appSupportURL.appendingPathComponent("planning_goals.json")
    }
    
    private var dayRecordsFileURL: URL {
        appSupportURL.appendingPathComponent("day_records.json")
    }
    
    private var dayModesFileURL: URL {
        appSupportURL.appendingPathComponent("day_modes.json")
    }
    
    private var journalsFileURL: URL {
        appSupportURL.appendingPathComponent("journals.json")
    }
    
    private var snapshotsFileURL: URL {
        appSupportURL.appendingPathComponent("day_snapshots.json")
    }
    
    private var settingsFileURL: URL {
        appSupportURL.appendingPathComponent("settings.json")
    }
    
    private var civilCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }
    
    // MARK: - Initialization
    init() {
        loadData()
        
        if goals.isEmpty {
            goals = Goal.samples
            saveGoals()
        }
        
        ensureDayModes()
        ensureDaySnapshotsCurrent()
    }
    
    // MARK: - Data Loading
    private func loadData() {
        loadGoals()
        loadEntries()
        loadPlanningGoals()
        loadDayRecords()
        loadDayModes()
        loadJournals()
        loadSnapshots()
        loadSettings()
    }
    
    private func loadGoals() {
        guard let data = try? Data(contentsOf: goalsFileURL),
              let decoded = try? JSONDecoder().decode([Goal].self, from: data) else {
            return
        }
        goals = decoded.sorted { $0.order < $1.order }
    }
    
    private func loadEntries() {
        guard let data = try? Data(contentsOf: entriesFileURL),
              let decoded = try? JSONDecoder().decode([GoalEntry].self, from: data) else {
            return
        }
        entries = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }
    
    private func loadPlanningGoals() {
        guard let data = try? Data(contentsOf: planningGoalsFileURL),
              let decoded = try? JSONDecoder().decode([PlanningGoal].self, from: data) else {
            return
        }
        planningGoals = decoded.sorted { $0.order < $1.order }
    }
    
    private func loadDayRecords() {
        guard let data = try? Data(contentsOf: dayRecordsFileURL),
              let decoded = try? JSONDecoder().decode([DayRecord].self, from: data) else {
            return
        }
        dayRecords = Dictionary(uniqueKeysWithValues: decoded.map { ($0.dateString, $0) })
    }
    
    private func loadDayModes() {
        guard let data = try? Data(contentsOf: dayModesFileURL),
              let decoded = try? JSONDecoder().decode([DayMode].self, from: data) else {
            return
        }
        dayModes = decoded.sorted { $0.order < $1.order }
    }
    
    private func loadJournals() {
        guard let data = try? Data(contentsOf: journalsFileURL),
              let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) else {
            return
        }
        journals = Dictionary(uniqueKeysWithValues: decoded.map { ($0.dateString, $0) })
    }
    
    private func loadSnapshots() {
        guard let data = try? Data(contentsOf: snapshotsFileURL),
              let decoded = try? JSONDecoder().decode([DaySnapshot].self, from: data) else {
            return
        }
        snapshots = Dictionary(uniqueKeysWithValues: decoded.map { ($0.dateString, $0) })
    }
    
    private func loadSettings() {
        guard let data = try? Data(contentsOf: settingsFileURL),
              let decoded = try? JSONDecoder().decode(TrackerSettings.self, from: data) else {
            return
        }
        settings = decoded
    }
    
    /// Seed default modes (and migrate old `isEssential` flags into accepted goal lists).
    private func ensureDayModes() {
        guard dayModes.isEmpty else { return }
        let essentialIds = goals.filter(\.isEssential).map(\.id)
        dayModes = DayMode.defaults(acceptedGoalIds: essentialIds)
        saveDayModes()
    }
    
    // MARK: - Data Saving
    private func saveGoals() {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        try? data.write(to: goalsFileURL)
    }
    
    private func saveEntries() {
        let entriesArray = Array(entries.values)
        guard let data = try? JSONEncoder().encode(entriesArray) else { return }
        try? data.write(to: entriesFileURL)
    }
    
    private func savePlanningGoals() {
        guard let data = try? JSONEncoder().encode(planningGoals) else { return }
        try? data.write(to: planningGoalsFileURL)
    }
    
    private func saveDayRecords() {
        let records = Array(dayRecords.values)
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: dayRecordsFileURL)
    }
    
    private func saveDayModes() {
        guard let data = try? JSONEncoder().encode(dayModes) else { return }
        try? data.write(to: dayModesFileURL)
    }
    
    private func saveJournals() {
        let entries = Array(journals.values)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: journalsFileURL)
    }
    
    private func saveSnapshots() {
        let records = Array(snapshots.values)
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: snapshotsFileURL)
    }
    
    func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsFileURL)
    }
    
    func updateSettings(_ mutate: (inout TrackerSettings) -> Void) {
        mutate(&settings)
        saveSettings()
        ensureDaySnapshotsCurrent()
    }
    
    // MARK: - Logical date / freeze
    
    /// Civil date that "now" belongs to, using day-start or Maghrib.
    func logicalDate(for now: Date = Date()) -> Date {
        computeLogicalDate(now)
    }
    
    func isLogicalToday(_ date: Date, now: Date = Date()) -> Bool {
        civilCalendar.isDate(date, inSameDayAs: computeLogicalDate(now))
    }
    
    /// Day lists can always be edited, including past snapshots. Freeze only stops the weekly template from rewriting history.
    func isPlanEditable(on date: Date, now: Date = Date()) -> Bool { true }
    
    /// True once this civil date has been snapshotted (template changes no longer rewrite it).
    func isMembershipFrozen(on date: Date, now: Date = Date()) -> Bool {
        let key = GoalEntry.dateString(from: date)
        if snapshots[key]?.frozen == true { return true }
        let today = computeLogicalDate(now)
        if civilCalendar.compare(GoalEntry.startOfCivilDay(for: date), to: today, toGranularity: .day) == .orderedAscending {
            return true
        }
        if civilCalendar.isDate(date, inSameDayAs: today) {
            return now >= dayEndInstant(for: today)
        }
        return false
    }
    
    /// Freeze yesterday (and today after day-end). Safe to call often.
    func ensureDaySnapshotsCurrent(now: Date = Date()) {
        let today = computeLogicalDate(now)
        if let yesterday = civilCalendar.date(byAdding: .day, value: -1, to: today) {
            freezeDayIfNeeded(yesterday, now: now)
        }
        freezeDayIfNeeded(today, now: now)
    }
    
    private func computeLogicalDate(_ now: Date) -> Date {
        let civil = GoalEntry.startOfCivilDay(for: now)
        
        if settings.dayStartsAtMaghrib, let maghrib = maghrib(on: civil) {
            if now >= maghrib {
                return civilCalendar.date(byAdding: .day, value: 1, to: civil) ?? civil
            }
            return civil
        }
        
        let start = timeOnDay(civil, minutes: settings.dayStartMinutes)
        if now < start {
            return civilCalendar.date(byAdding: .day, value: -1, to: civil) ?? civil
        }
        return civil
    }
    
    private func dayStartInstant(for logicalDate: Date) -> Date {
        let day = GoalEntry.startOfCivilDay(for: logicalDate)
        if settings.dayStartsAtMaghrib {
            let previous = civilCalendar.date(byAdding: .day, value: -1, to: day) ?? day
            if let maghrib = maghrib(on: previous) {
                return maghrib
            }
        }
        return timeOnDay(day, minutes: settings.dayStartMinutes)
    }
    
    private func dayEndInstant(for logicalDate: Date) -> Date {
        let day = GoalEntry.startOfCivilDay(for: logicalDate)
        if settings.dayStartsAtMaghrib, let maghrib = maghrib(on: day) {
            return maghrib
        }
        var end = timeOnDay(day, minutes: settings.dayEndMinutes)
        let start = dayStartInstant(for: day)
        if end <= start {
            end = civilCalendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return end
    }
    
    private func timeOnDay(_ day: Date, minutes: Int) -> Date {
        let clamped = TrackerSettings.clampedMinutes(minutes)
        return civilCalendar.date(byAdding: .minute, value: clamped, to: GoalEntry.startOfCivilDay(for: day))
            ?? GoalEntry.startOfCivilDay(for: day)
    }
    
    private func maghrib(on civilDay: Date) -> Date? {
        prayerService?.maghrib(on: civilDay)
    }
    
    private func freezeDayIfNeeded(_ date: Date, now: Date) {
        let day = GoalEntry.startOfCivilDay(for: date)
        let key = GoalEntry.dateString(from: day)
        if snapshots[key]?.frozen == true { return }
        
        let today = computeLogicalDate(now)
        let isPast = civilCalendar.compare(day, to: today, toGranularity: .day) == .orderedAscending
        let isTodayPastEnd = civilCalendar.isDate(day, inSameDayAs: today) && now >= dayEndInstant(for: day)
        guard isPast || isTodayPastEnd else { return }
        
        freezeDay(day)
    }
    
    private func freezeDay(_ date: Date) {
        let day = GoalEntry.startOfCivilDay(for: date)
        let key = GoalEntry.dateString(from: day)
        if snapshots[key]?.frozen == true { return }
        
        var snap = snapshots[key] ?? DaySnapshot(
            dateString: key,
            modeId: getDayRecord(for: day).modeId
        )
        let tracked = liveGoalsForDay(day).tracked
        snap.items = tracked.enumerated().map { index, goal in
            SnapshotItem(
                goalId: goal.id,
                title: goal.title,
                icon: goal.icon,
                order: index,
                isOverride: snap.extraSet.contains(goal.id) || snap.oneOffItems.contains { $0.goalId == goal.id },
                isOneOff: snap.oneOffItems.contains { $0.goalId == goal.id }
            )
        }
        snap.frozen = true
        snap.modeId = getDayRecord(for: day).modeId
        snap.oneOffItems = []
        snapshots[key] = snap
        saveSnapshots()
    }
    
    private func liveSnapshot(for date: Date) -> DaySnapshot {
        let key = GoalEntry.dateString(from: date)
        return snapshots[key] ?? DaySnapshot(
            dateString: key,
            modeId: getDayRecord(for: date).modeId
        )
    }
    
    private func mutateSnapshot(for date: Date, _ body: (inout DaySnapshot) -> Void) {
        let key = GoalEntry.dateString(from: date)
        var snap = liveSnapshot(for: date)
        body(&snap)
        snapshots[key] = snap
        saveSnapshots()
    }
    
    func hideGoal(_ goalId: UUID, on date: Date) {
        mutateSnapshot(for: date) { snap in
            if snap.frozen {
                snap.items.removeAll { $0.goalId == goalId }
                Self.reindex(&snap.items)
            } else if snap.oneOffItems.contains(where: { $0.goalId == goalId }) {
                snap.oneOffItems.removeAll { $0.goalId == goalId }
            } else {
                snap.extraGoalIds.removeAll { $0 == goalId }
                if !snap.hiddenGoalIds.contains(goalId) {
                    snap.hiddenGoalIds.append(goalId)
                }
            }
        }
    }
    
    func addGoalOverride(_ goalId: UUID, on date: Date) {
        guard let goal = goals.first(where: { $0.id == goalId }) else { return }
        mutateSnapshot(for: date) { snap in
            snap.hiddenGoalIds.removeAll { $0 == goalId }
            if snap.frozen {
                guard !snap.items.contains(where: { $0.goalId == goalId }) else { return }
                snap.items.append(
                    SnapshotItem(
                        goalId: goal.id,
                        title: goal.title,
                        icon: goal.icon,
                        order: snap.items.count,
                        isOverride: true
                    )
                )
            } else if !snap.extraGoalIds.contains(goalId) {
                snap.extraGoalIds.append(goalId)
            }
        }
    }
    
    func addOneOffTask(title: String, icon: String, on date: Date) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutateSnapshot(for: date) { snap in
            let item = SnapshotItem(
                goalId: UUID(),
                title: trimmed,
                icon: icon,
                order: snap.frozen ? snap.items.count : snap.oneOffItems.count,
                isOverride: true,
                isOneOff: true
            )
            if snap.frozen {
                snap.items.append(item)
            } else {
                snap.oneOffItems.append(item)
            }
        }
    }
    
    func isOneOff(_ goalId: UUID, on date: Date) -> Bool {
        let snap = snapshots[GoalEntry.dateString(from: date)]
        if let snap, snap.frozen {
            return snap.items.first(where: { $0.goalId == goalId })?.isOneOff == true
        }
        return snap?.oneOffItems.contains(where: { $0.goalId == goalId }) == true
    }
    
    func goalsAvailableToAdd(on date: Date) -> [Goal] {
        let trackedIds = Set(goalsForDay(date).tracked.map(\.id))
        return goals.filter { $0.isActive && !trackedIds.contains($0.id) }
    }
    
    private static func reindex(_ items: inout [SnapshotItem]) {
        for index in items.indices {
            items[index].order = index
        }
    }
    
    // MARK: - Goal Management
    func addGoal(_ goal: Goal) {
        var newGoal = goal
        newGoal.order = goals.count
        goals.append(newGoal)
        saveGoals()
    }
    
    func updateGoal(_ goal: Goal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            saveGoals()
        }
    }
    
    func setWeekdays(_ weekdays: WeekdaySet, for goalId: UUID) {
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[index].weekdays = weekdays.isEmpty ? goals[index].weekdays : weekdays
        saveGoals()
    }
    
    func toggleWeekday(_ weekday: WeekdaySet, for goalId: UUID) {
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else { return }
        var next = goals[index].weekdays
        if next.contains(weekday) {
            next.remove(weekday)
            if next.isEmpty { return }
        } else {
            next.insert(weekday)
        }
        goals[index].weekdays = next
        saveGoals()
    }
    
    func deleteGoal(_ goal: Goal) {
        goals.removeAll { $0.id == goal.id }
        for (index, _) in goals.enumerated() {
            goals[index].order = index
        }
        for i in dayModes.indices {
            dayModes[i].acceptedGoalIds.removeAll { $0 == goal.id }
        }
        for key in snapshots.keys {
            guard snapshots[key]?.frozen != true else { continue }
            snapshots[key]?.hiddenGoalIds.removeAll { $0 == goal.id }
            snapshots[key]?.extraGoalIds.removeAll { $0 == goal.id }
        }
        saveGoals()
        saveDayModes()
        saveSnapshots()
    }
    
    func moveGoal(from source: IndexSet, to destination: Int) {
        goals.move(fromOffsets: source, toOffset: destination)
        for (index, _) in goals.enumerated() {
            goals[index].order = index
        }
        saveGoals()
    }
    
    // MARK: - Entry Management
    func getEntry(for goalId: UUID, on date: Date) -> GoalEntry {
        let dateString = GoalEntry.dateString(from: date)
        let key = "\(goalId.uuidString)_\(dateString)"
        return entries[key] ?? GoalEntry(goalId: goalId, date: date)
    }
    
    func setStatus(_ status: GoalStatus, for goalId: UUID, on date: Date) {
        let dateString = GoalEntry.dateString(from: date)
        let key = "\(goalId.uuidString)_\(dateString)"
        
        if var entry = entries[key] {
            entry.status = status
            entries[key] = entry
        } else {
            let entry = GoalEntry(goalId: goalId, date: date, status: status)
            entries[key] = entry
        }
        saveEntries()
    }
    
    func cycleStatus(for goalId: UUID, on date: Date) {
        let entry = getEntry(for: goalId, on: date)
        setStatus(entry.status.next, for: goalId, on: date)
    }
    
    func setNote(_ note: String?, for goalId: UUID, on date: Date) {
        let dateString = GoalEntry.dateString(from: date)
        let key = "\(goalId.uuidString)_\(dateString)"
        
        if var entry = entries[key] {
            entry.note = note
            entries[key] = entry
        } else {
            var entry = GoalEntry(goalId: goalId, date: date)
            entry.note = note
            entries[key] = entry
        }
        saveEntries()
    }
    
    // MARK: - Day Modes
    
    var sortedDayModes: [DayMode] {
        dayModes.sorted { $0.order < $1.order }
    }
    
    func mode(for id: String) -> DayMode {
        dayModes.first { $0.id == id }
            ?? dayModes.first(where: \.tracksAllGoals)
            ?? DayMode.normalFallback
    }
    
    func mode(for date: Date) -> DayMode {
        let key = GoalEntry.dateString(from: date)
        if let snap = snapshots[key], snap.frozen {
            return mode(for: snap.modeId)
        }
        return mode(for: getDayRecord(for: date).modeId)
    }
    
    func addDayMode(_ mode: DayMode) {
        var newMode = mode
        newMode.order = dayModes.count
        dayModes.append(newMode)
        saveDayModes()
    }
    
    func updateDayMode(_ mode: DayMode) {
        guard let index = dayModes.firstIndex(where: { $0.id == mode.id }) else { return }
        var updated = mode
        if dayModes[index].id == DayMode.normalId {
            updated.tracksAllGoals = true
            updated.acceptedGoalIds = []
        }
        dayModes[index] = updated
        saveDayModes()
    }
    
    func deleteDayMode(_ mode: DayMode) {
        guard mode.id != DayMode.normalId, !mode.tracksAllGoals else { return }
        dayModes.removeAll { $0.id == mode.id }
        for (index, _) in dayModes.enumerated() {
            dayModes[index].order = index
        }
        let normalId = dayModes.first(where: \.tracksAllGoals)?.id ?? DayMode.normalId
        for key in dayRecords.keys {
            if dayRecords[key]?.modeId == mode.id {
                dayRecords[key]?.modeId = normalId
            }
        }
        dayRecords = dayRecords.filter { $0.value.modeId != normalId || $0.value.note != nil }
        saveDayModes()
        saveDayRecords()
    }
    
    func moveDayMode(from source: IndexSet, to destination: Int) {
        dayModes.move(fromOffsets: source, toOffset: destination)
        for (index, _) in dayModes.enumerated() {
            dayModes[index].order = index
        }
        saveDayModes()
    }
    
    func toggleAcceptedGoal(_ goalId: UUID, for modeId: String) {
        guard let index = dayModes.firstIndex(where: { $0.id == modeId }) else { return }
        guard !dayModes[index].tracksAllGoals else { return }
        if let existing = dayModes[index].acceptedGoalIds.firstIndex(of: goalId) {
            dayModes[index].acceptedGoalIds.remove(at: existing)
        } else {
            dayModes[index].acceptedGoalIds.append(goalId)
        }
        saveDayModes()
    }
    
    // MARK: - Day Mode (per date)
    
    func getDayRecord(for date: Date) -> DayRecord {
        let key = GoalEntry.dateString(from: date)
        return dayRecords[key] ?? DayRecord(date: date)
    }
    
    func setDayMode(_ mode: DayMode, for date: Date, note: String? = nil) {
        let key = GoalEntry.dateString(from: date)
        let resolved = self.mode(for: mode.id)
        if resolved.tracksAllGoals && note == nil {
            dayRecords.removeValue(forKey: key)
        } else {
            var record = dayRecords[key] ?? DayRecord(date: date)
            record.modeId = resolved.id
            if let note { record.note = note }
            dayRecords[key] = record
        }
        if var snap = snapshots[key] {
            snap.modeId = resolved.id
            snapshots[key] = snap
            saveSnapshots()
        }
        saveDayRecords()
    }
    
    // MARK: - Journal
    
    func journal(for date: Date) -> JournalEntry? {
        journals[GoalEntry.dateString(from: date)]
    }
    
    func journalText(for date: Date) -> String {
        journal(for: date)?.text ?? ""
    }
    
    func hasJournal(on date: Date) -> Bool {
        guard let entry = journal(for: date) else { return false }
        return !entry.isEmpty
    }
    
    func setJournal(_ text: String, for date: Date) {
        let key = GoalEntry.dateString(from: date)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if journals.removeValue(forKey: key) != nil {
                saveJournals()
            }
        } else if journals[key]?.text != text {
            journals[key] = JournalEntry(date: date, text: text)
            saveJournals()
        }
    }
    
    /// Goals that apply on a given day (template + mode + overrides, or frozen snapshot).
    func goalsForDay(_ date: Date) -> (tracked: [Goal], skipped: [Goal]) {
        let key = GoalEntry.dateString(from: date)
        if let snap = snapshots[key], snap.frozen {
            let tracked = snap.items.sorted { $0.order < $1.order }.map { $0.asGoal() }
            return (tracked, [])
        }
        return liveGoalsForDay(date)
    }
    
    private func liveGoalsForDay(_ date: Date) -> (tracked: [Goal], skipped: [Goal]) {
        let weekday = WeekdaySet.forDate(date, calendar: civilCalendar)
        let eligible = goals.filter { $0.isActive && $0.weekdays.contains(weekday) }
        let snap = snapshots[GoalEntry.dateString(from: date)]
        let hidden = snap?.hiddenSet ?? []
        let extraIds = snap?.extraGoalIds ?? []
        let dayMode = mode(for: getDayRecord(for: date).modeId)
        
        var tracked: [Goal]
        if dayMode.tracksAllGoals {
            tracked = eligible.filter { !hidden.contains($0.id) }
        } else {
            let accepted = Set(dayMode.acceptedGoalIds)
            tracked = eligible.filter { accepted.contains($0.id) && !hidden.contains($0.id) }
        }
        
        for extraId in extraIds {
            guard !tracked.contains(where: { $0.id == extraId }),
                  let extra = goals.first(where: { $0.id == extraId && $0.isActive })
            else { continue }
            tracked.append(extra)
        }
        
        if let oneOffs = snap?.oneOffItems {
            for item in oneOffs where !tracked.contains(where: { $0.id == item.goalId }) {
                tracked.append(item.asGoal())
            }
        }
        
        tracked.sort { $0.order < $1.order }
        let trackedIds = Set(tracked.map(\.id))
        let skipped = eligible.filter { !trackedIds.contains($0.id) }.sorted { $0.order < $1.order }
        return (tracked, skipped)
    }
    
    // MARK: - Statistics
    func getDailySummary(for date: Date) -> DailySummary {
        let dayMode = mode(for: date)
        let (tracked, skipped) = goalsForDay(date)
        let dayEntries = tracked.map { getEntry(for: $0.id, on: date) }
        return DailySummary(
            date: date,
            entries: dayEntries,
            totalGoals: tracked.count,
            dayMode: dayMode,
            skippedCount: skipped.count
        )
    }
    
    func getWeekEntries(for date: Date) -> [[GoalEntry]] {
        let dates = calendarPresentation.weekDates(containing: date)
        
        return goalsForWeek(dates).map { goal in
            dates.map { day in
                if isGoalTracked(goal, on: day) {
                    return getEntry(for: goal.id, on: day)
                }
                return GoalEntry(goalId: goal.id, date: day, status: .notDone)
            }
        }
    }
    
    func goalsForWeek(_ dates: [Date]) -> [Goal] {
        var ordered: [Goal] = []
        var seen = Set<UUID>()
        for date in dates {
            for goal in goalsForDay(date).tracked where seen.insert(goal.id).inserted {
                ordered.append(goal)
            }
        }
        return ordered
    }
    
    /// Whether a goal counts on a specific day (for week grid styling).
    func isGoalTracked(_ goal: Goal, on date: Date) -> Bool {
        goalsForDay(date).tracked.contains { $0.id == goal.id }
    }
    
    func getMonthEntries(for dates: [Date]) -> [Date: DailySummary] {
        var summaries: [Date: DailySummary] = [:]
        for date in dates {
            let key = GoalEntry.startOfCivilDay(for: date)
            summaries[key] = getDailySummary(for: key)
        }
        return summaries
    }
    
    func getMonthEntries(for date: Date) -> [Date: DailySummary] {
        let days = calendarPresentation.monthDayDates(containing: date)
        return getMonthEntries(for: days)
    }
    
    /// Streak: consecutive days meeting tracked goal target for that day's mode.
    func getCurrentStreak() -> Int {
        var streak = 0
        var currentDate = computeLogicalDate(Date())
        
        while true {
            let summary = getDailySummary(for: currentDate)
            let met: Bool
            if summary.totalGoals == 0 {
                met = summary.isSpecialDay
            } else {
                met = summary.completionPercentage >= 1.0
            }
            if met {
                streak += 1
                currentDate = civilCalendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        return streak
    }
    
    // MARK: - Planning Goals Management
    
    func getPlanningGoals(for horizon: PlanningHorizon, periodKey: String? = nil) -> [PlanningGoal] {
        let key = periodKey ?? horizon.periodKey()
        return planningGoals
            .filter { $0.horizon == horizon && $0.periodKey == key }
            .sorted { $0.order < $1.order }
    }
    
    func addPlanningGoal(_ goal: PlanningGoal) {
        var newGoal = goal
        let existingCount = getPlanningGoals(for: goal.horizon, periodKey: goal.periodKey).count
        newGoal.order = existingCount
        planningGoals.append(newGoal)
        savePlanningGoals()
    }
    
    func updatePlanningGoal(_ goal: PlanningGoal) {
        if let index = planningGoals.firstIndex(where: { $0.id == goal.id }) {
            planningGoals[index] = goal
            savePlanningGoals()
        }
    }
    
    func togglePlanningGoalCompletion(_ goalId: UUID) {
        if let index = planningGoals.firstIndex(where: { $0.id == goalId }) {
            planningGoals[index].isCompleted.toggle()
            planningGoals[index].completedAt = planningGoals[index].isCompleted ? Date() : nil
            savePlanningGoals()
        }
    }
    
    func deletePlanningGoal(_ goal: PlanningGoal) {
        planningGoals.removeAll { $0.id == goal.id }
        let goalsToReorder = getPlanningGoals(for: goal.horizon, periodKey: goal.periodKey)
        for (index, g) in goalsToReorder.enumerated() {
            if let i = planningGoals.firstIndex(where: { $0.id == g.id }) {
                planningGoals[i].order = index
            }
        }
        savePlanningGoals()
    }
    
    func movePlanningGoal(for horizon: PlanningHorizon, periodKey: String, from source: IndexSet, to destination: Int) {
        var goalsForPeriod = getPlanningGoals(for: horizon, periodKey: periodKey)
        goalsForPeriod.move(fromOffsets: source, toOffset: destination)
        
        for (index, goal) in goalsForPeriod.enumerated() {
            if let i = planningGoals.firstIndex(where: { $0.id == goal.id }) {
                planningGoals[i].order = index
            }
        }
        savePlanningGoals()
    }
    
    func getPlanningStats(for horizon: PlanningHorizon, periodKey: String? = nil) -> (completed: Int, total: Int) {
        let goals = getPlanningGoals(for: horizon, periodKey: periodKey)
        let completed = goals.filter { $0.isCompleted }.count
        return (completed, goals.count)
    }
}
