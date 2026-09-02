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
    
    // MARK: - Initialization
    init() {
        loadData()
        
        // Create sample goals if first launch
        if goals.isEmpty {
            goals = Goal.samples
            saveGoals()
        }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        loadGoals()
        loadEntries()
        loadPlanningGoals()
        loadDayRecords()
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
    
    func deleteGoal(_ goal: Goal) {
        goals.removeAll { $0.id == goal.id }
        // Reorder remaining goals
        for (index, _) in goals.enumerated() {
            goals[index].order = index
        }
        // Remove associated entries
        entries = entries.filter { !$0.key.hasPrefix(goal.id.uuidString) }
        saveGoals()
        saveEntries()
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
    
    // MARK: - Day Mode
    
    func getDayRecord(for date: Date) -> DayRecord {
        let key = GoalEntry.dateString(from: date)
        return dayRecords[key] ?? DayRecord(date: date)
    }
    
    func setDayMode(_ mode: DayMode, for date: Date, note: String? = nil) {
        let key = GoalEntry.dateString(from: date)
        if mode == .normal && note == nil {
            dayRecords.removeValue(forKey: key)
        } else {
            var record = dayRecords[key] ?? DayRecord(date: date)
            record.mode = mode
            if let note { record.note = note }
            dayRecords[key] = record
        }
        saveDayRecords()
    }
    
    /// Goals that apply on a given day (respects special-day essential filter).
    func goalsForDay(_ date: Date) -> (tracked: [Goal], skipped: [Goal]) {
        let active = goals.filter(\.isActive)
        let mode = getDayRecord(for: date).mode
        
        guard mode.tracksEssentialOnly else {
            return (active, [])
        }
        
        let essential = active.filter(\.isEssential)
        let skipped = active.filter { !$0.isEssential }
        return (essential, skipped)
    }
    
    // MARK: - Statistics
    func getDailySummary(for date: Date) -> DailySummary {
        let mode = getDayRecord(for: date).mode
        let (tracked, skipped) = goalsForDay(date)
        let dayEntries = tracked.map { getEntry(for: $0.id, on: date) }
        return DailySummary(
            date: date,
            entries: dayEntries,
            totalGoals: tracked.count,
            dayMode: mode,
            skippedCount: skipped.count
        )
    }
    
    func getWeekEntries(for date: Date) -> [[GoalEntry]] {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        
        return goals.filter { $0.isActive }.map { goal in
            (0..<7).map { dayOffset in
                let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                let (tracked, _) = goalsForDay(day)
                if tracked.contains(where: { $0.id == goal.id }) {
                    return getEntry(for: goal.id, on: day)
                }
                return GoalEntry(goalId: goal.id, date: day, status: .notDone)
            }
        }
    }
    
    /// Whether a goal counts on a specific day (for week grid styling).
    func isGoalTracked(_ goal: Goal, on date: Date) -> Bool {
        goalsForDay(date).tracked.contains { $0.id == goal.id }
    }
    
    func getMonthEntries(for date: Date) -> [Date: DailySummary] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)!
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        
        var summaries: [Date: DailySummary] = [:]
        for day in range {
            let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            summaries[dayDate] = getDailySummary(for: dayDate)
        }
        return summaries
    }
    
    /// Streak: consecutive days meeting tracked goal target (essential-only on special days).
    func getCurrentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
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
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        return streak
    }
    
    // MARK: - Planning Goals Management
    
    /// Get planning goals for a specific horizon and period
    func getPlanningGoals(for horizon: PlanningHorizon, periodKey: String? = nil) -> [PlanningGoal] {
        let key = periodKey ?? horizon.periodKey()
        return planningGoals
            .filter { $0.horizon == horizon && $0.periodKey == key }
            .sorted { $0.order < $1.order }
    }
    
    /// Add a new planning goal
    func addPlanningGoal(_ goal: PlanningGoal) {
        var newGoal = goal
        let existingCount = getPlanningGoals(for: goal.horizon, periodKey: goal.periodKey).count
        newGoal.order = existingCount
        planningGoals.append(newGoal)
        savePlanningGoals()
    }
    
    /// Update a planning goal
    func updatePlanningGoal(_ goal: PlanningGoal) {
        if let index = planningGoals.firstIndex(where: { $0.id == goal.id }) {
            planningGoals[index] = goal
            savePlanningGoals()
        }
    }
    
    /// Toggle planning goal completion
    func togglePlanningGoalCompletion(_ goalId: UUID) {
        if let index = planningGoals.firstIndex(where: { $0.id == goalId }) {
            planningGoals[index].isCompleted.toggle()
            planningGoals[index].completedAt = planningGoals[index].isCompleted ? Date() : nil
            savePlanningGoals()
        }
    }
    
    /// Delete a planning goal
    func deletePlanningGoal(_ goal: PlanningGoal) {
        planningGoals.removeAll { $0.id == goal.id }
        // Reorder remaining goals in same horizon/period
        let goalsToReorder = getPlanningGoals(for: goal.horizon, periodKey: goal.periodKey)
        for (index, g) in goalsToReorder.enumerated() {
            if let i = planningGoals.firstIndex(where: { $0.id == g.id }) {
                planningGoals[i].order = index
            }
        }
        savePlanningGoals()
    }
    
    /// Move planning goals within same horizon
    func movePlanningGoal(for horizon: PlanningHorizon, periodKey: String, from source: IndexSet, to destination: Int) {
        var goalsForPeriod = getPlanningGoals(for: horizon, periodKey: periodKey)
        goalsForPeriod.move(fromOffsets: source, toOffset: destination)
        
        // Update orders
        for (index, goal) in goalsForPeriod.enumerated() {
            if let i = planningGoals.firstIndex(where: { $0.id == goal.id }) {
                planningGoals[i].order = index
            }
        }
        savePlanningGoals()
    }
    
    /// Get completion stats for a horizon
    func getPlanningStats(for horizon: PlanningHorizon, periodKey: String? = nil) -> (completed: Int, total: Int) {
        let goals = getPlanningGoals(for: horizon, periodKey: periodKey)
        let completed = goals.filter { $0.isCompleted }.count
        return (completed, goals.count)
    }
}
