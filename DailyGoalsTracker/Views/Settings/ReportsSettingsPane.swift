import SwiftUI
import Charts

/// Library of weekly and monthly reports, in the Settings window.
struct ReportsSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(SettingsRouter.self) private var settingsRouter
    
    @State private var openedReportId: String?
    
    var body: some View {
        Group {
            if let openedReportId, let report = dataStore.periodReport(id: openedReportId) {
                PeriodReportReader(report: report) {
                    self.openedReportId = nil
                }
            } else {
                reportList
            }
        }
        .onAppear(perform: openPendingReport)
        .onChange(of: settingsRouter.reportIdToOpen) { _, _ in
            openPendingReport()
        }
    }
    
    private var reportList: some View {
        List {
            Section {
                Toggle("Weekly and monthly reports", isOn: periodReportsBinding)
            } footer: {
                Text("A notification arrives when a week or month ends. It uses the word task, and Apple Intelligence names the report.")
            }
            
            Section {
                LabeledContent("Apple Intelligence") {
                    Text(PeriodReportService.appleIntelligenceStatusText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section("Library") {
                if dataStore.periodReports.isEmpty {
                    Text("No reports yet. The first one appears after a week ends.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dataStore.periodReports) { report in
                        Button {
                            openedReportId = report.id
                        } label: {
                            ReportLibraryRow(report: report)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Reports")
    }
    
    private var periodReportsBinding: Binding<Bool> {
        Binding(
            get: { dataStore.settings.periodReportsEnabled },
            set: { newValue in
                dataStore.updateSettings { $0.periodReportsEnabled = newValue }
            }
        )
    }
    
    private func openPendingReport() {
        guard let id = settingsRouter.reportIdToOpen else { return }
        openedReportId = id
        settingsRouter.clearReportOpen()
    }
}

/// One row in the report library.
struct ReportLibraryRow: View {
    let report: PeriodReport
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: report.kind.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(report.kind == .week ? Color.blue : Color.indigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(report.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text("\(report.kind.title) · \(report.periodLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if !report.summary.isEmpty, report.summary != report.title {
                    Text(taskWording(report.summary))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Reading view: charts first, then what slipped, then notes that interpret the pattern.
struct PeriodReportReader: View {
    @Environment(DataStore.self) private var dataStore
    let report: PeriodReport
    let onBack: () -> Void
    
    private var days: [ReportDayBar] {
        if !report.dayBars.isEmpty { return report.dayBars }
        return dataStore.periodChart(from: report.periodStart, through: report.periodEnd).days
    }
    
    private var tasks: [ReportTaskBar] {
        if !report.taskBars.isEmpty { return report.taskBars }
        return dataStore.periodChart(from: report.periodStart, through: report.periodEnd).tasks
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                BackLinkButton(title: "Reports", helpText: "Back to reports", action: onBack)
                
                header
                dailyChart
                taskChart
                if !report.shortcomings.isEmpty {
                    insightSection(
                        title: "Shortcomings",
                        symbol: "exclamationmark.circle",
                        tint: .orange,
                        lines: report.shortcomings
                    )
                }
                if !report.suggestions.isEmpty {
                    insightSection(
                        title: "Ways to make these tasks easier",
                        symbol: "lightbulb",
                        tint: .blue,
                        lines: report.suggestions
                    )
                } else {
                    Text("Suggestions appear here after Apple Intelligence reads this period. Add how you work under Suggest AI so they fit you.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                notesSection
                if report.usedAppleIntelligence {
                    Label("Written with Apple Intelligence", systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Reports")
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var isRewritingNotes: Bool {
        dataStore.periodReportService?.rewritingReportId == report.id
    }
    
    private var notesError: String? {
        guard dataStore.periodReportService?.notesRewriteErrorReportId == report.id else { return nil }
        return dataStore.periodReportService?.notesRewriteError
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notes")
                    .font(.headline)
                Spacer(minLength: 12)
                Button {
                    Task { await dataStore.periodReportService?.rewriteNotes(for: report.id) }
                } label: {
                    if isRewritingNotes {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Redo", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(isRewritingNotes || !PeriodReportService.isAppleIntelligenceAvailable)
                .help("Rewrite the notes from the latest suggestions")
            }
            
            if let notesError {
                Text(notesError)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if report.paragraphs.isEmpty {
                Text("Notes say what this pattern leads to, what to add, and how to keep the tasks that already work.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(report.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(taskWording(paragraph))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.kind.title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text(report.title)
                .font(.title.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(report.periodLabel)
                .font(.title3)
                .foregroundStyle(.secondary)
            if !report.summary.isEmpty, report.summary != report.title {
                Text(taskWording(report.summary))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var dailyChart: some View {
        reportCard(title: "Each day", subtitle: "Share of tasks finished") {
            if days.isEmpty {
                Text("No days in this period.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(days) { day in
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Finished", day.percent)
                    )
                    .foregroundStyle(barColor(day.percent))
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let number = value.as(Int.self) {
                                Text("\(number)%")
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }
    
    private var taskChart: some View {
        reportCard(title: "Tasks", subtitle: "Lowest first, so the gaps are easy to see") {
            if tasks.isEmpty {
                Text("No tasks were tracked in this period.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(task.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text("\(task.percent)%")
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(barColor(task.percent))
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.08))
                                    Capsule()
                                        .fill(barColor(task.percent))
                                        .frame(width: geo.size.width * CGFloat(task.percent) / 100)
                                }
                            }
                            .frame(height: 8)
                            Text(taskCaption(task))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func insightSection(title: String, symbol: String, tint: Color, lines: [String]) -> some View {
        reportCard(title: title, subtitle: nil) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint)
                        Text(taskWording(line))
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
    
    private func reportCard<Content: View>(title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func barColor(_ percent: Int) -> Color {
        if percent >= 70 { return .green }
        if percent >= 40 { return .orange }
        return .red
    }
    
    private func taskCaption(_ task: ReportTaskBar) -> String {
        var parts = ["\(task.done) done"]
        if task.partial > 0 {
            parts.append("\(task.partial) partial")
        }
        parts.append("of \(task.tracked)")
        return parts.joined(separator: " · ")
    }
}

private func taskWording(_ text: String) -> String {
    text
        .replacingOccurrences(of: "goal-days", with: "task-days")
        .replacingOccurrences(of: "Goal-days", with: "Task-days")
        .replacingOccurrences(of: "goals", with: "tasks")
        .replacingOccurrences(of: "Goals", with: "Tasks")
        .replacingOccurrences(of: "goal", with: "task")
        .replacingOccurrences(of: "Goal", with: "Task")
}

#Preview("Reports") {
    ReportsSettingsPane()
        .environment(DataStore())
        .environment(SettingsRouter())
        .frame(width: 560, height: 520)
}
