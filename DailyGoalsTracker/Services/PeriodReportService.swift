import Foundation
import UserNotifications
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26, *)
@Generable
struct GeneratedPeriodReport {
    @Guide(description: "A short evocative title of 2 to 5 words. No dates, numbers, quotes, or punctuation.")
    var title: String
    
    @Guide(description: "One sentence under 140 characters for a notification. Call them tasks, never goals. Include one real number.")
    var summary: String
    
    @Guide(description: "Exactly four short paragraphs, separated by a blank line. Plain sentences. Call them tasks, never goals. No title, markdown, bullets, or repeated percentages and counts. 1) If they keep this pattern, what they will achieve and what stays unfinished. 2) What should be added. 3) What goes wrong if they neglect one task or focus only on another. 4) The best way to keep doing the tasks they already do well, using how they work.")
    var narrative: String
    
    @Guide(description: "Up to 4 short sentences. Each names a task that slipped and what got in the way. No guilt.")
    var shortcomings: [String]
    
    @Guide(description: "Up to 4 concrete ways to make the weakest tasks easier, using how the person says they work. Specific and encouraging.")
    var suggestions: [String]
}

@available(macOS 26, *)
@Generable
struct GeneratedReportName {
    @Guide(description: "A short evocative title of 2 to 5 words. No dates, numbers, quotes, or punctuation.")
    var title: String
    
    @Guide(description: "One sentence under 140 characters. Call them tasks, never goals. Include one real number.")
    var summary: String
}

@available(macOS 26, *)
@Generable
struct GeneratedReportAdvice {
    @Guide(description: "Up to 4 short sentences. Each names a task that slipped and what got in the way.")
    var shortcomings: [String]
    
    @Guide(description: "Up to 4 concrete ways to make the weakest tasks easier, using how the person says they work.")
    var suggestions: [String]
}

@available(macOS 26, *)
@Generable
struct GeneratedReportNotes {
    @Guide(description: "Exactly four short paragraphs, separated by a blank line. Plain sentences. Call them tasks, never goals. No title, markdown, bullets, or repeated percentages and counts. Reason from the latest suggestions without pasting them as a list. 1) If they keep this pattern, what they will achieve and what stays unfinished. 2) What should be added. 3) What goes wrong if they neglect one task or focus only on another. 4) The best way to keep doing the tasks they already do well, using how they work.")
    var narrative: String
}
#endif

/// Builds weekly / monthly fact sheets, optionally summarizes with Apple Intelligence, and notifies.
@Observable
final class PeriodReportService {
    static let categoryId = "period.report"
    static let idPrefix = "period.report."
    
    private weak var dataStore: DataStore?
    private var isGenerating = false
    private var titleRefreshCooldownUntil: Date?
    private var adviceRefreshCooldownUntil: Date?
    /// Report whose notes are being rewritten. The reader uses this for the Redo spinner.
    var rewritingReportId: String?
    /// Shown under Notes when a rewrite fails.
    var notesRewriteError: String?
    var notesRewriteErrorReportId: String?
    
    func attach(dataStore: DataStore) {
        self.dataStore = dataStore
    }
    
    func bootstrap() {
        Task { @MainActor in
            await requestAuthorization()
            registerCategories()
            await checkDueReports()
            await refreshUngeneratedTitles()
            await refreshMissingAdvice()
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
    
    // MARK: - Availability
    
    /// Whether on-device Apple Intelligence can write reports right now.
    static var appleIntelligenceStatusText: String {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "Apple Intelligence is available"
            case .unavailable(.deviceNotEligible):
                return "This Mac does not support Apple Intelligence"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence in System Settings"
            case .unavailable(.modelNotReady):
                return "Apple Intelligence model is still downloading"
            case .unavailable:
                return "Apple Intelligence is unavailable"
            }
        }
        #endif
        return "Requires macOS 26 with Apple Intelligence"
    }
    
    static var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
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
        let statsSummary = facts.notificationSummary
        let statsFull = facts.fullText
        
        var reportTitle = title
        var fullText = statsFull
        var summary = statsSummary
        var usedAI = false
        var titleIsGenerated = false
        var shortcomings: [String] = []
        var suggestions: [String] = []
        
        if let ai = await writeWithAppleIntelligence(facts: facts.promptText) {
            reportTitle = ai.title
            fullText = ai.narrative
            summary = ai.summary
            shortcomings = ai.shortcomings
            suggestions = ai.suggestions
            usedAI = true
            titleIsGenerated = true
        }
        
        let report = PeriodReport(
            id: id,
            kind: kind,
            title: reportTitle,
            periodStart: start,
            periodEnd: end,
            summary: summary,
            fullText: fullText,
            usedAppleIntelligence: usedAI,
            titleIsGenerated: titleIsGenerated,
            shortcomings: shortcomings,
            suggestions: suggestions,
            dayBars: facts.dayBars,
            taskBars: facts.taskBars
        )
        dataStore.upsertPeriodReport(report)
        postNotification(for: report)
    }
    
    private struct FactSheet {
        let promptText: String
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
        let style = dataStore.settings.workingStyleNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let styleBlock = style.isEmpty
            ? "How this person works best: not provided."
            : "How this person works best:\n\(style)"
        
        let promptText = """
        Write a personal progress report from the facts below.
        Use only these facts. Do not invent numbers, tasks, or events.
        Call the tracked items tasks, never goals.
        The title is a name for the period, not a date.
        The person already sees the charts and the task table, so the narrative must not repeat percentages, counts, or which days were high or low.
        
        Write the narrative as exactly four short paragraphs, separated by a blank line:
        1. If they keep doing what they are doing, what they will achieve and what will stay unfinished.
        2. What should be added.
        3. What goes wrong if they neglect one task, or if they focus only on a task they already do well.
        4. The best way to keep doing the tasks they already do well, using how they work.
        
        Shortcomings name the tasks that slipped, without restating the narrative.
        Suggestions are concrete ways to make the weakest tasks easier, using how this person works.
        
        \(styleBlock)
        
        \(fullText)
        """
        
        let chart = dataStore.periodChart(from: start, through: end)
        
        return FactSheet(
            promptText: promptText,
            fullText: fullText,
            notificationSummary: notificationSummary,
            dayBars: chart.days,
            taskBars: chart.tasks
        )
    }
    
    private struct WrittenReport {
        let title: String
        let summary: String
        let narrative: String
        let shortcomings: [String]
        let suggestions: [String]
    }
    
    private func writeWithAppleIntelligence(facts: String) async -> WrittenReport? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else { return nil }
            
            do {
                let session = LanguageModelSession(
                    instructions: """
                    You write a short personal progress report and give it a memorable name.
                    Call tracked items tasks, never goals.
                    Stay grounded in the provided facts. Plain language. No markdown.
                    The narrative predicts what continues, what to add, the cost of neglecting one task or focusing on another, and the best way to keep doing tasks that already work.
                    Do not restate the chart. Suggestions are specific ways to make weak tasks easier.
                    """
                )
                let response = try await session.respond(to: facts, generating: GeneratedPeriodReport.self)
                let draft = response.content
                let title = Self.cleanedTitle(draft.title)
                let narrative = Self.cleanedNarrative(draft.narrative)
                let summary = draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, !narrative.isEmpty else { return nil }
                return WrittenReport(
                    title: title,
                    summary: summary.isEmpty ? Self.notificationClip(from: narrative) : Self.notificationClip(from: summary),
                    narrative: narrative,
                    shortcomings: Self.cleanedLines(draft.shortcomings),
                    suggestions: Self.cleanedLines(draft.suggestions)
                )
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
    
    /// Rewrites the notes from a fresh set of suggestions, using the latest working-style notes.
    @MainActor
    func rewriteNotes(for reportId: String) async {
        guard rewritingReportId == nil else { return }
        guard let dataStore, var report = dataStore.periodReport(id: reportId) else { return }
        guard Self.isAppleIntelligenceAvailable else {
            notesRewriteError = "Turn on Apple Intelligence to rewrite the notes."
            notesRewriteErrorReportId = reportId
            return
        }
        
        rewritingReportId = reportId
        notesRewriteError = nil
        notesRewriteErrorReportId = nil
        defer { rewritingReportId = nil }
        
        let style = dataStore.settings.workingStyleNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        var adviceSource = report
        adviceSource.fullText = ""
        if let advice = await adviseExistingReport(adviceSource, workingStyle: style, dataStore: dataStore) {
            report.shortcomings = advice.shortcomings
            report.suggestions = advice.suggestions
        }
        
        guard let narrative = await writeInterpretiveNotes(report: report, workingStyle: style, dataStore: dataStore) else {
            if dataStore.periodReport(id: reportId)?.suggestions != report.suggestions {
                report.usedAppleIntelligence = true
                dataStore.upsertPeriodReport(report)
            }
            notesRewriteError = "Apple Intelligence could not rewrite the notes."
            notesRewriteErrorReportId = reportId
            return
        }
        
        report.fullText = Self.strippingLeadingHeading(narrative, heading: report.title)
        report.usedAppleIntelligence = true
        dataStore.upsertPeriodReport(report)
    }
    
    private func writeInterpretiveNotes(
        report: PeriodReport,
        workingStyle: String,
        dataStore: DataStore
    ) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else { return nil }
            
            let chart = (report.dayBars.isEmpty || report.taskBars.isEmpty)
                ? dataStore.periodChart(from: report.periodStart, through: report.periodEnd)
                : (days: report.dayBars, tasks: report.taskBars)
            let prompt = notesPrompt(report: report, chart: chart, workingStyle: workingStyle, dataStore: dataStore)
            
            do {
                let session = LanguageModelSession(
                    instructions: """
                    You rewrite the notes of a personal progress report.
                    The reader already has the charts, so do not repeat percentages, counts, or day scores.
                    Call tracked items tasks, never goals.
                    Stay grounded in the facts and the latest suggestions. Plain language. No markdown.
                    Predict what continues, what to add, the cost of neglecting one task or focusing on another, and the best way to keep doing tasks that already work.
                    """
                )
                let response = try await session.respond(to: prompt, generating: GeneratedReportNotes.self)
                let narrative = Self.cleanedNarrative(response.content.narrative)
                guard !narrative.isEmpty else { return nil }
                return narrative
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
    
    private func notesPrompt(
        report: PeriodReport,
        chart: (days: [ReportDayBar], tasks: [ReportTaskBar]),
        workingStyle: String,
        dataStore: DataStore
    ) -> String {
        func taskLine(_ task: ReportTaskBar) -> String {
            "\(task.title): \(task.percent)% (\(task.done) done, \(task.partial) partial, of \(task.tracked))"
        }
        
        let strong = chart.tasks.filter { $0.percent >= 70 }
        let slipping = chart.tasks.filter { $0.percent < 50 }
        let middle = chart.tasks.filter { $0.percent >= 50 && $0.percent < 70 }
        let strongerDays = chart.days.filter { $0.percent >= 70 }.map(\.label)
        let weakerDays = chart.days.filter { $0.percent < 40 }.map(\.label)
        
        let styleBlock = workingStyle.isEmpty
            ? "How this person works best: not provided."
            : "How this person works best:\n\(workingStyle)"
        let suggestionBlock = report.suggestions.isEmpty
            ? "Latest suggestions: none yet."
            : "Latest suggestions (reason from these, do not paste them as a list):\n" + report.suggestions.map { "- \($0)" }.joined(separator: "\n")
        let shortcomingBlock = report.shortcomings.isEmpty
            ? ""
            : "What already slipped:\n" + report.shortcomings.map { "- \($0)" }.joined(separator: "\n")
        
        let days = dates(from: report.periodStart, through: report.periodEnd)
        let context = periodContext(
            start: report.periodStart,
            end: GoalEntry.startOfCivilDay(for: report.periodEnd),
            days: days,
            dataStore: dataStore
        )
        
        var lines = [
            "Rewrite the notes for this \(report.kind.title.lowercased()) report (\(report.periodLabel)).",
            "The person can already see the charts and the task table. Do not repeat percentages, counts, or which days scored high or low.",
            "",
            "Write exactly four short paragraphs, separated by a blank line:",
            "1. If they keep doing what they are doing, what they will achieve and what will stay unfinished.",
            "2. What should be added.",
            "3. What goes wrong if they neglect one task, or if they focus only on another.",
            "4. The best way to keep doing the tasks they already do well, using how they work.",
            "",
            "Use only these facts. Do not invent tasks, projects, or events.",
            "",
            styleBlock,
            "",
            suggestionBlock,
        ]
        if !shortcomingBlock.isEmpty {
            lines.append("")
            lines.append(shortcomingBlock)
        }
        lines.append("")
        lines.append("Tasks they already do well:")
        lines.append(contentsOf: listed(strong.map(taskLine), empty: "None stood out."))
        lines.append("Tasks in the middle:")
        lines.append(contentsOf: listed(middle.map(taskLine), empty: "None."))
        lines.append("Tasks that slipped:")
        lines.append(contentsOf: listed(slipping.map(taskLine), empty: "None stood out."))
        lines.append("Stronger days: \(named(strongerDays))")
        lines.append("Weaker days: \(named(weakerDays))")
        if !context.projects.isEmpty {
            lines.append("Projects:")
            lines.append(contentsOf: context.projects.map { "- \($0)" })
        }
        if !context.journal.isEmpty {
            lines.append("Journal snippets:")
            lines.append(contentsOf: context.journal.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }
    
    private func listed(_ items: [String], empty: String) -> [String] {
        items.isEmpty ? [empty] : items.map { "- \($0)" }
    }
    
    private func named(_ labels: [String]) -> String {
        labels.isEmpty ? "none" : labels.joined(separator: ", ")
    }
    
    private func dates(from start: Date, through end: Date) -> [Date] {
        let calendar = Calendar(identifier: .gregorian)
        var cursor = GoalEntry.startOfCivilDay(for: start)
        let last = GoalEntry.startOfCivilDay(for: end)
        var dates: [Date] = []
        while cursor <= last {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
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
            guard let journal = dataStore.journal(for: date), !journal.isEmpty else { continue }
            let plain = journal.preview
            guard !plain.isEmpty else { continue }
            let clipped = String(plain.prefix(120))
            journalSnippets.append("\(GoalEntry.dateString(from: date)): \(clipped)")
            journalChars += clipped.count
            if journalChars > 600 { break }
        }
        
        return (projectLines, journalSnippets)
    }
    
    /// Names reports that were saved before titles were generated.
    @MainActor
    func refreshUngeneratedTitles() async {
        guard let dataStore else { return }
        if let until = titleRefreshCooldownUntil, until > Date() { return }
        let pending = dataStore.periodReports.filter { !$0.titleIsGenerated }
        guard !pending.isEmpty, Self.isAppleIntelligenceAvailable else { return }
        
        for report in pending {
            guard let naming = await nameExistingReport(report) else {
                titleRefreshCooldownUntil = Date().addingTimeInterval(60 * 30)
                return
            }
            var updated = report
            updated.title = naming.title
            updated.summary = naming.summary
            updated.fullText = Self.strippingLeadingHeading(report.fullText, heading: report.title)
            updated.titleIsGenerated = true
            updated.usedAppleIntelligence = true
            dataStore.upsertPeriodReport(updated)
        }
    }
    
    /// Fills shortcomings and suggestions on reports saved before that section existed.
    @MainActor
    func refreshMissingAdvice() async {
        guard let dataStore else { return }
        if let until = adviceRefreshCooldownUntil, until > Date() { return }
        let pending = dataStore.periodReports.filter { $0.suggestions.isEmpty }
        guard !pending.isEmpty, Self.isAppleIntelligenceAvailable else { return }
        
        let style = dataStore.settings.workingStyleNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        for report in pending {
            guard let advice = await adviseExistingReport(report, workingStyle: style, dataStore: dataStore) else {
                adviceRefreshCooldownUntil = Date().addingTimeInterval(60 * 30)
                return
            }
            var updated = report
            updated.shortcomings = advice.shortcomings
            updated.suggestions = advice.suggestions
            updated.usedAppleIntelligence = true
            if updated.dayBars.isEmpty {
                let chart = dataStore.periodChart(from: report.periodStart, through: report.periodEnd)
                updated.dayBars = chart.days
                updated.taskBars = chart.tasks
            }
            dataStore.upsertPeriodReport(updated)
        }
    }
    
    private func adviseExistingReport(
        _ report: PeriodReport,
        workingStyle: String,
        dataStore: DataStore
    ) async -> (shortcomings: [String], suggestions: [String])? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else { return nil }
            let chart = dataStore.periodChart(from: report.periodStart, through: report.periodEnd)
            let taskLines = chart.tasks.prefix(12).map { "\($0.title): \($0.percent)% (\($0.done) done, \($0.partial) partial, of \($0.tracked))" }
            let styleBlock = workingStyle.isEmpty
                ? "How this person works best: not provided."
                : "How this person works best:\n\(workingStyle)"
            let prompt = """
            Name the tasks that slipped and suggest concrete ways to make them easier.
            Use only these facts. Call them tasks, never goals. Do not invent numbers.
            
            \(styleBlock)
            
            \(taskLines.joined(separator: "\n"))
            
            \(report.fullText)
            """
            do {
                let session = LanguageModelSession(
                    instructions: "You help someone finish daily tasks. Be specific, encouraging, and grounded in the facts."
                )
                let response = try await session.respond(to: prompt, generating: GeneratedReportAdvice.self)
                let shortcomings = Self.cleanedLines(response.content.shortcomings)
                let suggestions = Self.cleanedLines(response.content.suggestions)
                guard !suggestions.isEmpty else { return nil }
                return (shortcomings, suggestions)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
    
    private static func cleanedLines(_ lines: [String]) -> [String] {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(4)
            .map { String($0) }
    }
    
    /// Turns a model draft into four prose paragraphs, dropping numbering the guide asked it not to use.
    private static func cleanedNarrative(_ raw: String) -> String {
        let text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        
        let blocks = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let pieces: [String]
        if blocks.count >= 2 {
            pieces = blocks
        } else {
            let lines = text
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            pieces = lines.count >= 3 ? lines : [text]
        }
        
        return pieces
            .map { piece in
                var line = piece
                if let range = line.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
                    line.removeSubrange(range)
                }
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
    
    private func nameExistingReport(_ report: PeriodReport) async -> (title: String, summary: String)? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else { return nil }
            let prompt = """
            Name this personal progress report and write a one-sentence summary.
            Use only what is written below. Do not invent numbers.
            
            \(report.fullText)
            """
            do {
                let session = LanguageModelSession(
                    instructions: "You name personal progress reports. The title is 2 to 5 words and is not a date."
                )
                let response = try await session.respond(to: prompt, generating: GeneratedReportName.self)
                let title = Self.cleanedTitle(response.content.title)
                let summary = response.content.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                return (title, Self.notificationClip(from: summary.isEmpty ? report.summary : summary))
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
    
    private static func cleanedTitle(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”"))
        if title.count > 48 {
            let end = title.index(title.startIndex, offsetBy: 48)
            title = String(title[..<end]).trimmingCharacters(in: .whitespaces)
        }
        return title
    }
    
    private static func strippingLeadingHeading(_ text: String, heading: String) -> String {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let first = lines.first?.trimmingCharacters(in: .whitespaces),
              first.caseInsensitiveCompare(heading) == .orderedSame else {
            return text
        }
        return lines.dropFirst()
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func notificationClip(from text: String) -> String {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        let first = lines.first(where: { !$0.isEmpty }) ?? text
        if first.count <= 160 { return first }
        let idx = first.index(first.startIndex, offsetBy: 157)
        return String(first[..<idx]) + "…"
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
