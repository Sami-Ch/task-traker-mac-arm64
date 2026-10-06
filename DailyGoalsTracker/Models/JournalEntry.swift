import AppKit
import Foundation

/// One freeform journal page keyed to a calendar day.
struct JournalEntry: Identifiable, Codable, Equatable {
    var id: String { dateString }
    let date: Date
    /// Plain text for previews, search, word count, and report snippets.
    var text: String
    /// RTF blob for the rich text editor. Nil for legacy markdown-only entries.
    var rtfData: Data?
    /// The user marked this day secure. It stays encrypted in Selected days mode.
    var markedSecure: Bool
    /// AES-GCM combined box. Present only while this day is sealed on disk or in memory.
    var sealedPayload: Data?
    var updatedAt: Date
    
    var dateString: String {
        GoalEntry.dateString(from: date)
    }
    
    var isSealed: Bool { sealedPayload != nil }
    
    var isEmpty: Bool {
        if isSealed { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// First couple of non-empty lines for the popover card.
    var preview: String {
        if isSealed { return "" }
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.prefix(2).joined(separator: " ")
    }
    
    var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }.count
    }
    
    var characterCount: Int {
        text.count
    }
    
    /// Reading time estimate at ~200 words per minute.
    var readingTimeMinutes: Int {
        max(1, (wordCount + 100) / 200)
    }
    
    init(date: Date, text: String, rtfData: Data? = nil, markedSecure: Bool = false, sealedPayload: Data? = nil, updatedAt: Date = Date()) {
        self.date = GoalEntry.startOfCivilDay(for: date)
        self.text = text
        self.rtfData = rtfData
        self.markedSecure = markedSecure
        self.sealedPayload = sealedPayload
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case date, text, rtfData, updatedAt, markedSecure, sealedPayload
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedDate = try container.decode(Date.self, forKey: .date)
        date = GoalEntry.startOfCivilDay(for: decodedDate)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        rtfData = try container.decodeIfPresent(Data.self, forKey: .rtfData)
        markedSecure = try container.decodeIfPresent(Bool.self, forKey: .markedSecure) ?? false
        sealedPayload = try container.decodeIfPresent(Data.self, forKey: .sealedPayload)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(rtfData, forKey: .rtfData)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(markedSecure, forKey: .markedSecure)
        try container.encodeIfPresent(sealedPayload, forKey: .sealedPayload)
    }
    
    /// Returns NSAttributedString from RTF data, or nil if not available.
    func attributedString() -> NSAttributedString? {
        guard let data = rtfData else { return nil }
        return NSAttributedString(rtf: data, documentAttributes: nil)
    }
    
    /// Creates a JournalEntry from an NSAttributedString, extracting plain text automatically.
    static func from(attributedString: NSAttributedString, date: Date) -> JournalEntry {
        let plainText = attributedString.string
        let rtf = attributedString.rtf(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [:])
        return JournalEntry(date: date, text: plainText, rtfData: rtf)
    }
}
