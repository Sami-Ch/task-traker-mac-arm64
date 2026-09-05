import Foundation

/// One freeform journal page keyed to a calendar day.
struct JournalEntry: Identifiable, Codable, Equatable {
    var id: String { dateString }
    let date: Date
    var text: String
    var updatedAt: Date
    
    var dateString: String {
        GoalEntry.dateString(from: date)
    }
    
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// First couple of non-empty lines, collapsed for the popover card.
    var preview: String {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.prefix(2).joined(separator: " ")
    }
    
    var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }.count
    }
    
    init(date: Date, text: String, updatedAt: Date = Date()) {
        self.date = Calendar.current.startOfDay(for: date)
        self.text = text
        self.updatedAt = updatedAt
    }
}
