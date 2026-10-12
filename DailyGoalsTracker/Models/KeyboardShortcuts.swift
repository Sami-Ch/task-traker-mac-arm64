import AppKit
import Carbon.HIToolbox
import Foundation

extension Notification.Name {
    /// Posted when `TrackerSettings.shortcuts` changes so global hotkeys can re-register.
    static let keyboardShortcutsDidChange = Notification.Name("keyboardShortcutsDidChange")
    /// Insert the open day's tasks into the journal. The journal window handles it.
    static let insertJournalTaskTemplate = Notification.Name("insertJournalTaskTemplate")
}

/// One key + modifier combination, stored for Carbon hotkeys and local matching.
struct KeyChord: Codable, Equatable, Hashable {
    var keyCode: UInt16
    /// Carbon modifier bits: `cmdKey`, `shiftKey`, `optionKey`, `controlKey`.
    var carbonModifiers: UInt32
    
    static let openTasksDefault = KeyChord(
        keyCode: UInt16(kVK_ANSI_Y),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )
    static let openJournalDefault = KeyChord(
        keyCode: UInt16(kVK_ANSI_Y),
        carbonModifiers: UInt32(cmdKey | controlKey)
    )
    static let journalPreviousDayDefault = KeyChord(
        keyCode: UInt16(kVK_LeftArrow),
        carbonModifiers: UInt32(cmdKey | optionKey)
    )
    static let journalNextDayDefault = KeyChord(
        keyCode: UInt16(kVK_RightArrow),
        carbonModifiers: UInt32(cmdKey | optionKey)
    )
    /// Previous default. ⌘← / ⌘→ belong to the text caret, so saved copies of that pair move forward.
    fileprivate static let retiredJournalPreviousDay = KeyChord(
        keyCode: UInt16(kVK_LeftArrow),
        carbonModifiers: UInt32(cmdKey)
    )
    fileprivate static let retiredJournalNextDay = KeyChord(
        keyCode: UInt16(kVK_RightArrow),
        carbonModifiers: UInt32(cmdKey)
    )
    static let insertJournalTasksDefault = KeyChord(
        keyCode: UInt16(kVK_ANSI_J),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )
    
    var hasModifier: Bool {
        carbonModifiers & UInt32(cmdKey | shiftKey | optionKey | controlKey) != 0
    }
    
    /// At least ⌘ or ⌃ — required for reliable global hotkeys and to avoid typing collisions.
    var isValidShortcut: Bool {
        let cmdOrCtrl = carbonModifiers & UInt32(cmdKey | controlKey) != 0
        return cmdOrCtrl && keyCode != UInt16(kVK_Escape)
    }
    
    var nsEventModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        return flags
    }
    
    var displayString: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keySymbol(for: keyCode))
        return parts.joined()
    }
    
    /// Character for `NSMenuItem.keyEquivalent` when possible; empty if unsupported.
    var menuKeyEquivalent: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_LeftArrow: return "\u{F702}"
        case kVK_RightArrow: return "\u{F703}"
        case kVK_UpArrow: return "\u{F700}"
        case kVK_DownArrow: return "\u{F701}"
        case kVK_Space: return " "
        case kVK_Return: return "\r"
        case kVK_Tab: return "\t"
        case kVK_Delete: return "\u{8}"
        case kVK_ForwardDelete: return "\u{7F}"
        default: return ""
        }
    }
    
    func matches(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown || event.type == .keyUp else { return false }
        guard event.keyCode == keyCode else { return false }
        let relevant: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        return event.modifierFlags.intersection(relevant) == nsEventModifiers
    }
    
    static func from(event: NSEvent) -> KeyChord? {
        let relevant: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let flags = event.modifierFlags.intersection(relevant)
        // Ignore bare modifier presses and Escape (cancel).
        if event.keyCode == UInt16(kVK_Escape) { return nil }
        if [kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
            kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl]
            .contains(Int(event.keyCode)) {
            return nil
        }
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        let chord = KeyChord(keyCode: event.keyCode, carbonModifiers: carbon)
        return chord.isValidShortcut ? chord : nil
    }
    
    private static func keySymbol(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "⎋"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Grave: return "`"
        default: return "Key\(keyCode)"
        }
    }
}

/// User-customizable shortcuts for the app and journal.
struct AppKeyboardShortcuts: Codable, Equatable {
    var openTasks: KeyChord
    var openJournal: KeyChord
    var journalPreviousDay: KeyChord
    var journalNextDay: KeyChord
    var insertJournalTasks: KeyChord
    
    static let `default` = AppKeyboardShortcuts(
        openTasks: .openTasksDefault,
        openJournal: .openJournalDefault,
        journalPreviousDay: .journalPreviousDayDefault,
        journalNextDay: .journalNextDayDefault,
        insertJournalTasks: .insertJournalTasksDefault
    )
    
    init(
        openTasks: KeyChord = .openTasksDefault,
        openJournal: KeyChord = .openJournalDefault,
        journalPreviousDay: KeyChord = .journalPreviousDayDefault,
        journalNextDay: KeyChord = .journalNextDayDefault,
        insertJournalTasks: KeyChord = .insertJournalTasksDefault
    ) {
        self.openTasks = openTasks
        self.openJournal = openJournal
        self.journalPreviousDay = journalPreviousDay
        self.journalNextDay = journalNextDay
        self.insertJournalTasks = insertJournalTasks
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        openTasks = try c.decodeIfPresent(KeyChord.self, forKey: .openTasks) ?? .openTasksDefault
        openJournal = try c.decodeIfPresent(KeyChord.self, forKey: .openJournal) ?? .openJournalDefault
        let storedPrevious = try c.decodeIfPresent(KeyChord.self, forKey: .journalPreviousDay)
        let storedNext = try c.decodeIfPresent(KeyChord.self, forKey: .journalNextDay)
        journalPreviousDay = storedPrevious == KeyChord.retiredJournalPreviousDay || storedPrevious == nil
            ? .journalPreviousDayDefault
            : storedPrevious!
        journalNextDay = storedNext == KeyChord.retiredJournalNextDay || storedNext == nil
            ? .journalNextDayDefault
            : storedNext!
        insertJournalTasks = try c.decodeIfPresent(KeyChord.self, forKey: .insertJournalTasks) ?? .insertJournalTasksDefault
    }
    
    /// First conflicting pair label, if any.
    var conflictDescription: String? {
        let pairs: [(String, KeyChord)] = [
            ("Open Tasks", openTasks),
            ("Open Journal", openJournal),
            ("Previous Day", journalPreviousDay),
            ("Next Day", journalNextDay),
            ("Insert Tasks", insertJournalTasks)
        ]
        for i in 0..<pairs.count {
            for j in (i + 1)..<pairs.count where pairs[i].1 == pairs[j].1 {
                return "\(pairs[i].0) and \(pairs[j].0) use the same shortcut."
            }
        }
        return nil
    }
}
