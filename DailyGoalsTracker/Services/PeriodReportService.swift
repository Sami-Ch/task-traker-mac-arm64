import Foundation
import UserNotifications

/// Builds weekly / monthly fact sheets and notifies when a period ends.
@Observable
final class PeriodReportService {
    static let categoryId = "period.report"
    static let idPrefix = "period.report."
    
    private weak var dataStore: DataStore?
    private var isGenerating = false
    
    func attach(dataStore: DataStore) {
        self.dataStore = dataStore
    }
    
    func bootstrap() {
        Task { @MainActor in
            await requestAuthorization()
            registerCategories()
            await checkDueReports()
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
        let category = UNNotificationCategory(
            identifier: Self.categoryId,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { existing in
            var merged = existing
            merged.insert(category)
            center.setNotificationCategories(merged)
        }
    }
    
    // MARK: - Due checks
    
    @MainActor
    func checkDueReports() async {
        guard let dataStore else { return }
        guard dataStore.settings.periodReportsEnabled else { return }
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        
        let today = dataStore.logicalDate()
        let presentation = dataStore.calendarPresentation
        
        if let week = presentation.previousCompletedWeek(relativeTo: today) {
            let id = "week:\(GoalEntry.dateString(from: week.start))"
            if dataStore.periodReport(id: id) == nil {
                await generateAndStore(
                    id: id,
                    kind: .week,
                    title: weekTitle(start: week.start, end: week.end, presentation: presentation),
                    start: week.start,
                    end: week.end,
                    dataStore: dataStore
                )
            }
        }
        
        if let month = presentation.previousCompletedMonth(relativeTo: today) {
            let id = monthPeriodId(start: month.start, presentation: presentation)
            if dataStore.periodReport(id: id) == nil {
                await generateAndStore(
                    id: id,
                    kind: .month,
                    title: month.title,
                    start: month.start,
                    end: month.end,
                    dataStore: dataStore
                )
            }
        }
    }
    
    // MARK: - Generation
    
    @MainActor
    private func generateAndStore(
        id: String,
        kind: PeriodReportKind,
        title: String,
        start: Date,
        end: Date,
        dataStore: DataStore
    ) async {
        let facts = buildFactSheet(kind: kind, title: title, start: start, end: end, dataStore: dataStore)
        
        let report = PeriodReport(
            id: id,
            kind: kind,
            title: title,
            periodStart: start,
            periodEnd: end,
            summary: facts.notificationSummary,
            fullText: facts.fullText,
            usedAppleIntelligence: false,
            titleIsGenerated: false,
            shortcomings: [],
            suggestions: [],
            dayBars: facts.dayBars,
            taskBars: facts.taskBars
        )
        dataStore.upsertPeriodReport(report)
        postNotification(for: report)
    }
    
    private struct FactSheet {
        let fullText: String
        let notificationSummary: String
        let dayBars: [ReportDayBar]
        let taskBars: [ReportTaskBar]
    }
    
    private func buildFactSheet(
        kind: PeriodReportKind,
        title: String,
        start: Date,
        end: Date,
        dataStore: DataStore
    ) -> FactSheet {
        let cal = Calendar(identifier: .gregorian)
        var days: [Date] = []
        var day = GoalEntry.startOfCivilDay(for: start)
        let last = GoalEntry.startOfCivilDay(for: end)
        while day <= last {
            days.append(day)
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        
        var totalTracked = 0
        var totalDone = 0
        var totalPartial = 0
        var totalNotDone = 0
        var perfectDays = 0
        var dayLines: [String] = []
        var goalDone: [UUID: (title: String, done: Int, tracked: Int)] = [:]
        
        for date in days {
            let summary = dataStore.getDailySummary(for: date)
            totalTracked += summary.totalGoals
            totalDone += summary.doneCount
            totalPartial += summary.partialCount
            totalNotDone += summary.notDoneCount
            if summary.totalGoals > 0 && summary.completionPercentage >= 1.0 {
                perfectDays += 1
            }
            
            let dayLabel = GoalEntry.dateString(from: date)
            let pct = Int(summary.completionPercentage * 100)
            dayLines.append(
                "\(dayLabel): \(summary.doneCount)/\(summary.totalGoals) done (\(pct)%), mode \(summary.dayMode.title)"
            )
            
            for entry in summary.entries {
                let goalTitle = dataStore.goals.first(where: { $0.id == entry.goalId })?.title
                    ?? "Task"
                var bucket = goalDone[entry.goalId] ?? (goalTitle, 0, 0)
                bucket.tracked += 1
                if entry.status == .done {
                    bucket.done += 1
                } else if entry.status == .partial {
                    // Count partial as half in narrative only via rates; still track as attempted
                }
                goalDone[entry.goalId] = bucket
            }
        }
        
        let avgPct: Int
        if totalTracked > 0 {
            let weighted = Double(totalDone) + Double(totalPartial) * 0.5
            avgPct = Int((weighted / Double(totalTracked)) * 100)
        } else {
            avgPct = 0
        }
        
        let context = periodContext(start: start, end: last, days: days, dataStore: dataStore)
        let projectLines = context.projects
        let journalSnippets = context.journal
        
        let topGoals = goalDone.values
            .sorted { $0.done > $1.done }
            .prefix(8)
            .map { "\($0.title): \($0.done)/\($0.tracked) days done" }
        
        let kindLabel = kind == .week ? "Week" : "Month"
        var lines: [String] = [
            "\(kindLabel) report: \(title)",
            "Range: \(GoalEntry.dateString(from: start)) – \(GoalEntry.dateString(from: end))",
            "Days tracked: \(days.count)",
            "Overall: \(avgPct)% (done \(totalDone), partial \(totalPartial), missed \(totalNotDone) of \(totalTracked) task-days)",
            "Perfect days: \(perfectDays)/\(days.count)",
        ]
        
        if !topGoals.isEmpty {
            lines.append("Tasks:")
            lines.append(contentsOf: topGoals.map { "- \($0)" })
        }
        if !projectLines.isEmpty {
            lines.append("Projects:")
            lines.append(contentsOf: projectLines.map { "- \($0)" })
        }
        if !journalSnippets.isEmpty {
            lines.append("Journal snippets:")
            lines.append(contentsOf: journalSnippets.map { "- \($0)" })
        }
        lines.append("Daily breakdown:")
        lines.append(contentsOf: dayLines)
        
        let fullText = lines.joined(separator: "\n")
        let notificationSummary = "\(avgPct)% of tasks · \(perfectDays) full day\(perfectDays == 1 ? "" : "s")"
        let chart = dataStore.periodChart(from: start, through: end)
        
        return FactSheet(
            fullText: fullText,
            notificationSummary: notificationSummary,
            dayBars: chart.days,
            taskBars: chart.tasks
        )
    }
    
    private func periodContext(
        start: Date,
        end: Date,
        days: [Date],
        dataStore: DataStore
    ) -> (projects: [String], journal: [String]) {
        let rangeStart = GoalEntry.startOfCivilDay(for: start)
        let completedProjects = dataStore.projects.filter { project in
            guard project.isCompleted, let completedAt = project.completedAt else { return false }
            let day = GoalEntry.startOfCivilDay(for: completedAt)
            return day >= rangeStart && day <= end
        }
        
        var projectLines: [String] = completedProjects.map { "Completed project: \($0.title)" }
        let activeProjects = dataStore.projects.filter { $0.isActive || $0.isPaused }
        for project in activeProjects.prefix(8) {
            let progress = dataStore.projectProgress(for: project)
            projectLines.append(
                "Active: \(project.title) — \(progress.overallProgressPercent)% (\(progress.completedMilestones)/\(progress.totalMilestones) milestones)"
            )
        }
        
        var journalSnippets: [String] = []
        var journalChars = 0
        for date in days {
            guard let journal = dataStore.journal(for: date), !journal.isEmpty, !journal.isSealed else { continue }
            let plain = journal.preview
            guard !plain.isEmpty else { continue }
            let clipped = String(plain.prefix(120))
            journalSnippets.append("\(GoalEntry.dateString(from: date)): \(clipped)")
            journalChars += clipped.count
            if journalChars > 600 { break }
        }
        
        return (projectLines, journalSnippets)
    }
    
    // MARK: - Titles / ids
    
    private func weekTitle(start: Date, end: Date, presentation: CalendarPresentation) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "Week of \(formatter.string(from: start))"
    }
    
    private func monthPeriodId(start: Date, presentation: CalendarPresentation) -> String {
        let cal = presentation.mode == .hijri
            ? presentation.hijriCalendar
            : presentation.gregorianCalendar
        let comps = cal.dateComponents([.year, .month], from: start)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        return String(format: "month:%04d-%02d", year, month)
    }
    
    // MARK: - Notify
    
    private func postNotification(for report: PeriodReport) {
        let content = UNMutableNotificationContent()
        content.title = report.title
        content.body = report.summary
        content.sound = .default
        content.categoryIdentifier = Self.categoryId
        content.userInfo = [
            "reportId": report.id,
            "kind": report.kind.rawValue
        ]
        
        let request = UNNotificationRequest(
            identifier: "\(Self.idPrefix)\(report.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    static func reportId(from response: UNNotificationResponse) -> String? {
        response.notification.request.content.userInfo["reportId"] as? String
    }
}
