import AppKit
import Foundation

enum JournalSavePhase: Equatable {
    case saved
    case saving
    case failed(String)
}

/// One row in the journal sidebar.
struct JournalDayListItem: Identifiable, Equatable {
    var date: Date
    var title: String
    var preview: String
    var sealed: Bool
    var wordCount: Int
    var id: String { GoalEntry.dateString(from: date) }
}
struct JournalCatalogEntry: Codable, Equatable, Identifiable {
    var date: Date
    var updatedAt: Date
    var preview: String
    var wordCount: Int
    var characterCount: Int
    var markedSecure: Bool
    var sealed: Bool
    /// Shown even while the day's writing is sealed. The page body stays encrypted.
    var title: String

    var id: String { dateString }

    var dateString: String {
        GoalEntry.dateString(from: date)
    }
    
    init(
        date: Date,
        updatedAt: Date,
        preview: String,
        wordCount: Int,
        characterCount: Int,
        markedSecure: Bool,
        sealed: Bool,
        title: String = ""
    ) {
        self.date = date
        self.updatedAt = updatedAt
        self.preview = preview
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.markedSecure = markedSecure
        self.sealed = sealed
        self.title = title
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        preview = try container.decodeIfPresent(String.self, forKey: .preview) ?? ""
        wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        characterCount = try container.decodeIfPresent(Int.self, forKey: .characterCount) ?? 0
        markedSecure = try container.decodeIfPresent(Bool.self, forKey: .markedSecure) ?? false
        sealed = try container.decodeIfPresent(Bool.self, forKey: .sealed) ?? false
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    }
}

private struct JournalFileError: LocalizedError {
    static let writeFailed = JournalFileError()
    var errorDescription: String? { "The journal could not be saved." }
}

private struct JournalVaultFile: Codable {
    var vault: JournalVaultRecord?
    var scope: JournalLockScope
}

/// One rich-text file per day, plus a small catalog and the password vault.
final class JournalStore {
    private let fileManager = FileManager.default
    private let rootURL: URL
    private let legacyURL: URL
    private let journalLock: JournalLock

    /// Titles of sealed days, filled only while the journal is unlocked. Not written to the catalog.
    private var sealedTitles: [String: String] = [:]
    private(set) var catalog: [String: JournalCatalogEntry] = [:]
    /// Plain text cached while the journal is unlocked. Dropped on lock. Never written for sealed days.
    private var sessionText: [String: String] = [:]

    init(appSupportURL: URL, journalLock: JournalLock) {
        rootURL = appSupportURL.appendingPathComponent("Journal", isDirectory: true)
        legacyURL = appSupportURL.appendingPathComponent("journals.json")
        self.journalLock = journalLock
    }

    func load() {
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: pagesURL, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: catalogURL.path),
           fileManager.fileExists(atPath: legacyURL.path) {
            migrateLegacy()
        }
        if let data = try? Data(contentsOf: catalogURL),
           let rows = try? JSONDecoder().decode([JournalCatalogEntry].self, from: data) {
            catalog = Dictionary(uniqueKeysWithValues: rows.map { ($0.dateString, $0) })
        }
        if let data = try? Data(contentsOf: vaultURL),
           let file = try? JSONDecoder().decode(JournalVaultFile.self, from: data) {
            journalLock.adopt(record: file.vault, scope: file.scope)
        }
    }

    /// Full page for the editor. Sealed days stay sealed until the key is in memory.
    func loadBody(for date: Date) -> JournalEntry? {
        let key = GoalEntry.dateString(from: date)
        guard let row = catalog[key] else { return nil }
        if row.sealed {
            guard let sealed = readSealedEntry(key: key, row: row) else { return nil }
            guard journalLock.isUnlocked, let opened = journalLock.reveal(sealed) else { return sealed }
            return opened
        }
        return readRTFEntry(key: key, row: row)
    }

    /// Decrypts at most once per unlock so previews can show without keeping RTF in memory.
    func plainTextForDisplay(on date: Date) -> String? {
        let key = GoalEntry.dateString(from: date)
        if let cached = sessionText[key] { return cached }
        guard journalLock.isUnlocked, catalog[key]?.sealed == true else { return nil }
        guard let body = loadBody(for: date), !body.isSealed else { return nil }
        sessionText[key] = body.text
        return body.text
    }

    /// Confirms the in-memory key can open sealed pages. Checks a single day.
    func canOpenASealedPage() -> Bool {
        guard let pair = catalog.first(where: { $0.value.sealed }) else { return true }
        guard let sealed = readSealedEntry(key: pair.key, row: pair.value) else { return false }
        return journalLock.reveal(sealed) != nil
    }

    func save(attributedString: NSAttributedString, date: Date) throws {
        let key = GoalEntry.dateString(from: date)
        if catalog[key]?.sealed == true && !journalLock.isUnlocked {
            throw JournalLockError.locked
        }
        let plain = attributedString.string
        let keptTitle = catalog[key]?.title ?? ""
        if plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if keptTitle.isEmpty {
                try removeDay(key)
            } else {
                try keepTitleOnlyDay(key: key, date: date, title: keptTitle)
            }
            return
        }
        let marked = catalog[key]?.markedSecure ?? false
        let rtf = attributedString.rtf(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [:]
        )
        let entry = JournalEntry(
            date: date,
            text: plain,
            title: keptTitle,
            rtfData: rtf,
            markedSecure: marked,
            updatedAt: Date()
        )
        try store(entry)
    }
    
    /// Updates the day's name without rewriting the page file.
    func setTitle(_ title: String, date: Date) throws {
        let key = GoalEntry.dateString(from: date)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if catalog[key]?.sealed == true {
            if journalLock.isUnlocked,
               let row = catalog[key],
               let sealed = readSealedEntry(key: key, row: row),
               var opened = journalLock.reveal(sealed) {
                opened.title = trimmed
                try store(opened)
            } else {
                catalog[key]?.title = trimmed
                catalog[key]?.updatedAt = Date()
                try writeCatalog()
            }
            sealedTitles[key] = trimmed
            return
        }
        if catalog[key] == nil {
            guard !trimmed.isEmpty else { return }
            catalog[key] = JournalCatalogEntry(
                date: GoalEntry.startOfCivilDay(for: date),
                updatedAt: Date(),
                preview: "",
                wordCount: 0,
                characterCount: 0,
                markedSecure: false,
                sealed: false,
                title: trimmed
            )
            try writeCatalog()
            return
        }
        catalog[key]?.title = trimmed
        catalog[key]?.updatedAt = Date()
        if trimmed.isEmpty && !fileManager.fileExists(atPath: rtfURL(key).path) {
            try removeDay(key)
            return
        }
        try writeCatalog()
    }
    
    /// Name shown in the sidebar. The catalog keeps it after the journal locks.
    func visibleTitle(on date: Date) -> String {
        let key = GoalEntry.dateString(from: date)
        if let title = catalog[key]?.title, !title.isEmpty {
            return title
        }
        return sealedTitles[key] ?? ""
    }
    
    func rememberSealedTitles() {
        sealedTitles = [:]
        guard journalLock.isUnlocked else { return }
        var restored = false
        for key in Array(catalog.keys) {
            guard let row = catalog[key], row.sealed else { continue }
            guard let sealed = readSealedEntry(key: key, row: row),
                  let opened = journalLock.reveal(sealed) else { continue }
            sealedTitles[key] = opened.title
            if row.title.isEmpty, !opened.title.isEmpty {
                catalog[key]?.title = opened.title
                restored = true
            }
        }
        if restored {
            try? writeCatalog()
        }
    }
    
    /// Copies names learned while unlocked into the catalog so locking does not drop them.
    func persistSealedTitles() {
        var changed = false
        for (key, title) in sealedTitles where !title.isEmpty {
            guard catalog[key]?.title != title else { continue }
            catalog[key]?.title = title
            changed = true
        }
        if changed {
            try? writeCatalog()
        }
    }
    
    func clearSealedTitles() {
        sealedTitles = [:]
    }
    
    private func keepTitleOnlyDay(key: String, date: Date, title: String) throws {
        catalog[key] = JournalCatalogEntry(
            date: GoalEntry.startOfCivilDay(for: date),
            updatedAt: Date(),
            preview: "",
            wordCount: 0,
            characterCount: 0,
            markedSecure: catalog[key]?.markedSecure ?? false,
            sealed: false,
            title: title
        )
        sessionText[key] = ""
        try writeCatalog()
        try deleteIfExists(rtfURL(key))
        try deleteIfExists(sealedURL(key))
    }

    func setMarkedSecure(_ secure: Bool, date: Date) throws {
        if journalLock.scope == .all { return }
        guard journalLock.hasPassword else { throw JournalLockError.passwordRequired }
        guard journalLock.isUnlocked else { throw JournalLockError.locked }
        let key = GoalEntry.dateString(from: date)
        guard catalog[key] != nil else { return }
        guard let body = loadBody(for: date), !body.isSealed else { return }
        var entry = body
        entry.markedSecure = secure
        entry.sealedPayload = nil
        try store(entry)
    }

    func saveVault() throws {
        let file = JournalVaultFile(vault: journalLock.record, scope: journalLock.scope)
        let data = try JSONEncoder().encode(file)
        try atomicWrite(data, to: vaultURL)
    }

    /// Encrypts plaintext pages that the current scope says should be sealed.
    func sealForLock() throws {
        guard journalLock.isUnlocked else { return }
        for key in Array(catalog.keys) {
            guard let row = catalog[key], !row.sealed else { continue }
            guard journalLock.shouldSeal(markedSecure: row.markedSecure) else { continue }
            guard let entry = readRTFEntry(key: key, row: row) else { continue }
            try store(entry)
        }
        sessionText.removeAll()
    }

    /// Seal or unseal pages so disk matches the scope that was just selected.
    func rewriteForCurrentScope() throws {
        guard journalLock.isUnlocked else { throw JournalLockError.locked }
        for key in Array(catalog.keys) {
            guard let row = catalog[key] else { continue }
            let should = journalLock.shouldSeal(markedSecure: row.markedSecure)
            if should && row.sealed { continue }
            if !should && !row.sealed { continue }
            if should {
                guard let entry = readRTFEntry(key: key, row: row) else { continue }
                try store(entry)
            } else {
                guard let sealed = readSealedEntry(key: key, row: row),
                      var opened = journalLock.reveal(sealed) else { continue }
                opened.markedSecure = row.markedSecure
                opened.sealedPayload = nil
                try store(opened)
            }
        }
        try saveVault()
    }

    /// Writes every day as plain RTF and clears the secure flags. The key must still be in memory.
    func removeAllProtection() throws {
        guard journalLock.isUnlocked else { throw JournalLockError.locked }
        for key in Array(catalog.keys) {
            guard let row = catalog[key] else { continue }
            if row.sealed {
                guard let sealed = readSealedEntry(key: key, row: row),
                      var opened = journalLock.reveal(sealed) else { continue }
                opened.markedSecure = false
                opened.sealedPayload = nil
                try writePlain(opened)
            } else {
                catalog[key]?.markedSecure = false
            }
        }
        sessionText.removeAll()
        try writeCatalog()
    }

    // MARK: - Files

    private var pagesURL: URL {
        rootURL.appendingPathComponent("pages", isDirectory: true)
    }

    private var catalogURL: URL {
        rootURL.appendingPathComponent("catalog.json")
    }

    private var vaultURL: URL {
        rootURL.appendingPathComponent("vault.json")
    }

    private func rtfURL(_ key: String) -> URL {
        pagesURL.appendingPathComponent("\(key).rtf")
    }

    private func sealedURL(_ key: String) -> URL {
        pagesURL.appendingPathComponent("\(key).sealed")
    }

    /// Writes the new body first, then the catalog, then removes the other form of the file.
    private func store(_ entry: JournalEntry) throws {
        let key = entry.dateString
        let prepared = journalLock.prepareForDisk(entry)
        if prepared.isSealed, let payload = prepared.sealedPayload {
            try atomicWrite(payload, to: sealedURL(key))
            sealedTitles[key] = entry.title
            catalog[key] = JournalCatalogEntry(
                date: entry.date,
                updatedAt: Date(),
                preview: "",
                wordCount: entry.wordCount,
                characterCount: entry.characterCount,
                markedSecure: prepared.markedSecure,
                sealed: true,
                title: entry.title
            )
            sessionText[key] = entry.text
            try writeCatalog()
            try deleteIfExists(rtfURL(key))
            return
        }
        guard let rtf = rtfData(for: entry) else { throw JournalFileError.writeFailed }
        try atomicWrite(rtf, to: rtfURL(key))
        catalog[key] = JournalCatalogEntry(
            date: entry.date,
            updatedAt: Date(),
            preview: Self.preview(from: entry.text),
            wordCount: entry.wordCount,
            characterCount: entry.characterCount,
            markedSecure: entry.markedSecure,
            sealed: false,
            title: entry.title
        )
        sessionText[key] = entry.text
        sealedTitles.removeValue(forKey: key)
        try writeCatalog()
        try deleteIfExists(sealedURL(key))
    }

    private func writePlain(_ entry: JournalEntry) throws {
        let key = entry.dateString
        guard let rtf = rtfData(for: entry) else { return }
        try atomicWrite(rtf, to: rtfURL(key))
        catalog[key] = JournalCatalogEntry(
            date: entry.date,
            updatedAt: Date(),
            preview: Self.preview(from: entry.text),
            wordCount: entry.wordCount,
            characterCount: entry.characterCount,
            markedSecure: false,
            sealed: false,
            title: entry.title
        )
        try writeCatalog()
        try deleteIfExists(sealedURL(key))
    }

    private func removeDay(_ key: String) throws {
        let previous = catalog[key]
        catalog.removeValue(forKey: key)
        sessionText.removeValue(forKey: key)
        do {
            try writeCatalog()
        } catch {
            if let previous {
                catalog[key] = previous
            }
            throw error
        }
        try deleteIfExists(rtfURL(key))
        try deleteIfExists(sealedURL(key))
    }

    private func readRTFEntry(key: String, row: JournalCatalogEntry) -> JournalEntry? {
        guard let data = try? Data(contentsOf: rtfURL(key)) else { return nil }
        let text = NSAttributedString(rtf: data, documentAttributes: nil)?.string ?? ""
        return JournalEntry(
            date: row.date,
            text: text,
            title: row.title,
            rtfData: data,
            markedSecure: row.markedSecure,
            updatedAt: row.updatedAt
        )
    }

    private func readSealedEntry(key: String, row: JournalCatalogEntry) -> JournalEntry? {
        guard let payload = try? Data(contentsOf: sealedURL(key)) else { return nil }
        return JournalEntry(
            date: row.date,
            text: "",
            markedSecure: row.markedSecure,
            sealedPayload: payload,
            updatedAt: row.updatedAt
        )
    }

    private func rtfData(for entry: JournalEntry) -> Data? {
        if let rtf = entry.rtfData { return rtf }
        let source = entry.text.isEmpty
            ? JournalRichText.defaultAttributedString()
            : JournalRichText.fromMarkdown(entry.text)
        return source.rtf(from: NSRange(location: 0, length: source.length), documentAttributes: [:])
    }

    private func writeCatalog() throws {
        let rows = catalog.values.sorted { $0.dateString < $1.dateString }
        let data = try JSONEncoder().encode(rows)
        try atomicWrite(data, to: catalogURL)
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    private func deleteIfExists(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private static func preview(from text: String) -> String {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.prefix(2).joined(separator: " ")
    }

    // MARK: - Migration from journals.json

    private func migrateLegacy() {
        guard let data = try? Data(contentsOf: legacyURL) else { return }
        let entries: [JournalEntry]
        if let document = try? JSONDecoder().decode(JournalDocument.self, from: data) {
            journalLock.adopt(record: document.vault, scope: document.scope)
            entries = document.entries
        } else if let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded
        } else {
            return
        }
        let previous = catalog
        catalog = [:]
        for entry in entries {
            do {
                try importLegacy(entry)
            } catch {
                catalog = previous
                return
            }
        }
        do {
            try writeCatalog()
            try saveVault()
            let dest = legacyURL.appendingPathExtension("migrated")
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.moveItem(at: legacyURL, to: dest)
        } catch {
            catalog = previous
            return
        }
    }

    private func importLegacy(_ entry: JournalEntry) throws {
        let trimmed = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if entry.sealedPayload == nil && trimmed.isEmpty { return }
        let key = entry.dateString
        if let payload = entry.sealedPayload {
            try atomicWrite(payload, to: sealedURL(key))
            catalog[key] = JournalCatalogEntry(
                date: entry.date,
                updatedAt: entry.updatedAt,
                preview: "",
                wordCount: 0,
                characterCount: 0,
                markedSecure: entry.markedSecure,
                sealed: true,
                title: entry.title
            )
            return
        }
        let text: String
        let rtf: Data?
        if let existing = entry.rtfData {
            rtf = existing
            text = entry.text
        } else {
            let attr = JournalRichText.fromMarkdown(entry.text)
            text = attr.string
            rtf = attr.rtf(from: NSRange(location: 0, length: attr.length), documentAttributes: [:])
        }
        guard let rtf else { throw JournalFileError.writeFailed }
        try atomicWrite(rtf, to: rtfURL(key))
        let page = JournalEntry(date: entry.date, text: text, title: entry.title, markedSecure: entry.markedSecure, updatedAt: entry.updatedAt)
        catalog[key] = JournalCatalogEntry(
            date: entry.date,
            updatedAt: entry.updatedAt,
            preview: Self.preview(from: text),
            wordCount: page.wordCount,
            characterCount: page.characterCount,
            markedSecure: entry.markedSecure,
            sealed: false,
            title: entry.title
        )
    }
}
