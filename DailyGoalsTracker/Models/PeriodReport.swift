import Foundation

/// One day in a report chart. `percent` is 0...100.
struct ReportDayBar: Codable, Equatable, Hashable, Identifiable {
    var id: String { dateString }
    let dateString: String
    var label: String
    var percent: Int
}

/// One task's completion across the report period.
struct ReportTaskBar: Codable, Equatable, Hashable, Identifiable {
    var id: String { title }
    var title: String
    var done: Int
    var partial: Int
    var tracked: Int
    var percent: Int
    
    var slipped: Bool { percent < 50 }
}
enum PeriodReportKind: String, Codable, CaseIterable, Identifiable {
    case week
    case month
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .week: return "Weekly"
        case .month: return "Monthly"
        }
    }
    
    var symbolName: String {
        switch self {
        case .week: return "calendar"
        case .month: return "calendar.circle"
        }
    }
}

/// One stored weekly or monthly report (facts + summary, optionally AI-written).
struct PeriodReport: Identifiable, Equatable, Hashable {
    /// Stable key, e.g. `week:2026-09-22` or `month:2026-09`.
    let id: String
    var kind: PeriodReportKind
    /// Short name. Apple Intelligence writes this when available.
    var title: String
    var periodStart: Date
    var periodEnd: Date
    /// Short line for the notification body and list preview.
    var summary: String
    /// Narrative shown in the reader.
    var fullText: String
    var usedAppleIntelligence: Bool
    /// True once Apple Intelligence has named this report.
    var titleIsGenerated: Bool
    var shortcomings: [String]
    var suggestions: [String]
    var dayBars: [ReportDayBar]
    var taskBars: [ReportTaskBar]
    var createdAt: Date
    
    init(
        id: String,
        kind: PeriodReportKind,
        title: String,
        periodStart: Date,
        periodEnd: Date,
        summary: String,
        fullText: String,
        usedAppleIntelligence: Bool,
        titleIsGenerated: Bool = false,
        shortcomings: [String] = [],
        suggestions: [String] = [],
        dayBars: [ReportDayBar] = [],
        taskBars: [ReportTaskBar] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.periodStart = GoalEntry.startOfCivilDay(for: periodStart)
        self.periodEnd = GoalEntry.startOfCivilDay(for: periodEnd)
        self.summary = summary
        self.fullText = fullText
        self.usedAppleIntelligence = usedAppleIntelligence
        self.titleIsGenerated = titleIsGenerated
        self.shortcomings = shortcomings
        self.suggestions = suggestions
        self.dayBars = dayBars
        self.taskBars = taskBars
        self.createdAt = createdAt
    }
    
    /// Factual date range, kept separate from the generated name.
    var periodLabel: String {
        if kind == .month {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: periodStart)
        }
        
        let calendar = Calendar.current
        let day = DateFormatter()
        day.dateFormat = "d"
        let monthYear = DateFormatter()
        monthYear.dateFormat = "MMM yyyy"
        let dayMonth = DateFormatter()
        dayMonth.dateFormat = "d MMM"
        let dayMonthYear = DateFormatter()
        dayMonthYear.dateFormat = "d MMM yyyy"
        
        if calendar.isDate(periodStart, equalTo: periodEnd, toGranularity: .month) {
            return "\(day.string(from: periodStart))–\(day.string(from: periodEnd)) \(monthYear.string(from: periodEnd))"
        }
        if calendar.isDate(periodStart, equalTo: periodEnd, toGranularity: .year) {
            return "\(dayMonth.string(from: periodStart)) – \(dayMonthYear.string(from: periodEnd))"
        }
        return "\(dayMonthYear.string(from: periodStart)) – \(dayMonthYear.string(from: periodEnd))"
    }
    
    /// Narrative split into paragraphs, dropping a leftover date heading.
    var paragraphs: [String] {
        let blocks = fullText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleaned = blocks.filter { block in
            let firstLine = block.split(whereSeparator: \.isNewline).first.map(String.init) ?? block
            let normalized = firstLine.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            return normalized.caseInsensitiveCompare(title) != .orderedSame || block.contains("\n")
        }
        return cleaned.isEmpty ? blocks : cleaned
    }
}

extension PeriodReport: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, kind, title, periodStart, periodEnd, summary, fullText
        case usedAppleIntelligence, titleIsGenerated, createdAt
        case shortcomings, suggestions, dayBars, taskBars
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(PeriodReportKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        periodStart = try container.decode(Date.self, forKey: .periodStart)
        periodEnd = try container.decode(Date.self, forKey: .periodEnd)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        fullText = try container.decodeIfPresent(String.self, forKey: .fullText) ?? ""
        usedAppleIntelligence = try container.decodeIfPresent(Bool.self, forKey: .usedAppleIntelligence) ?? false
        titleIsGenerated = try container.decodeIfPresent(Bool.self, forKey: .titleIsGenerated) ?? false
        shortcomings = try container.decodeIfPresent([String].self, forKey: .shortcomings) ?? []
        suggestions = try container.decodeIfPresent([String].self, forKey: .suggestions) ?? []
        dayBars = try container.decodeIfPresent([ReportDayBar].self, forKey: .dayBars) ?? []
        taskBars = try container.decodeIfPresent([ReportTaskBar].self, forKey: .taskBars) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(periodStart, forKey: .periodStart)
        try container.encode(periodEnd, forKey: .periodEnd)
        try container.encode(summary, forKey: .summary)
        try container.encode(fullText, forKey: .fullText)
        try container.encode(usedAppleIntelligence, forKey: .usedAppleIntelligence)
        try container.encode(titleIsGenerated, forKey: .titleIsGenerated)
        try container.encode(shortcomings, forKey: .shortcomings)
        try container.encode(suggestions, forKey: .suggestions)
        try container.encode(dayBars, forKey: .dayBars)
        try container.encode(taskBars, forKey: .taskBars)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
