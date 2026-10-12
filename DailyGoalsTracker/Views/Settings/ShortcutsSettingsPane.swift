import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutsSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    
    @State private var recording: ShortcutID?
    @State private var errorMessage: String?
    
    private enum ShortcutID: String, Identifiable {
        case openTasks
        case openJournal
        case journalPreviousDay
        case journalNextDay
        case insertJournalTasks
        var id: String { rawValue }
    }
    
    var body: some View {
        Form {
            Section {
                Text("Click a shortcut, then press the new keys. Include ⌘ or ⌃. Press Esc to cancel.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            Section("App") {
                shortcutRow(
                    title: "Open Tasks",
                    help: "Global — works while other apps are focused",
                    id: .openTasks,
                    chord: dataStore.settings.shortcuts.openTasks,
                    defaultChord: .openTasksDefault
                )
                shortcutRow(
                    title: "Open Journal",
                    help: "Global — works while other apps are focused",
                    id: .openJournal,
                    chord: dataStore.settings.shortcuts.openJournal,
                    defaultChord: .openJournalDefault
                )
            }
            
            Section("Journal") {
                shortcutRow(
                    title: "Previous Day",
                    help: "When the journal window is focused",
                    id: .journalPreviousDay,
                    chord: dataStore.settings.shortcuts.journalPreviousDay,
                    defaultChord: .journalPreviousDayDefault
                )
                shortcutRow(
                    title: "Next Day",
                    help: "When the journal window is focused",
                    id: .journalNextDay,
                    chord: dataStore.settings.shortcuts.journalNextDay,
                    defaultChord: .journalNextDayDefault
                )
                shortcutRow(
                    title: "Insert Tasks",
                    help: "Adds that day's tasks so you can write about each one",
                    id: .insertJournalTasks,
                    chord: dataStore.settings.shortcuts.insertJournalTasks,
                    defaultChord: .insertJournalTasksDefault
                )
            }
            
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            
            Section {
                Button("Reset All to Defaults") {
                    apply { $0 = .default }
                }
            }
        }
        .formStyle(.grouped)
        .background(
            ShortcutRecorderHost(
                isRecording: recording != nil,
                onCapture: { chord in
                    guard let recording else { return }
                    assign(chord, to: recording)
                    self.recording = nil
                },
                onCancel: {
                    recording = nil
                }
            )
        )
    }
    
    @ViewBuilder
    private func shortcutRow(
        title: String,
        help: String,
        id: ShortcutID,
        chord: KeyChord,
        defaultChord: KeyChord
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                errorMessage = nil
                recording = id
            } label: {
                Text(recording == id ? "Press keys…" : chord.displayString)
                    .font(.system(.body, design: .rounded).monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(recording == id ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .help(recording == id ? "Press a new shortcut, or Esc to cancel" : "Click to change")
            
            if chord != defaultChord {
                Button("Reset") {
                    assign(defaultChord, to: id)
                }
                .font(.caption)
            }
        }
    }
    
    private func assign(_ chord: KeyChord, to id: ShortcutID) {
        errorMessage = nil
        var next = dataStore.settings.shortcuts
        switch id {
        case .openTasks: next.openTasks = chord
        case .openJournal: next.openJournal = chord
        case .journalPreviousDay: next.journalPreviousDay = chord
        case .journalNextDay: next.journalNextDay = chord
        case .insertJournalTasks: next.insertJournalTasks = chord
        }
        if let conflict = next.conflictDescription {
            errorMessage = conflict
            return
        }
        apply { $0 = next }
    }
    
    private func apply(_ mutate: (inout AppKeyboardShortcuts) -> Void) {
        dataStore.updateSettings { settings in
            mutate(&settings.shortcuts)
        }
        errorMessage = nil
    }
}

/// Captures the next key combination while a row is recording.
private struct ShortcutRecorderHost: NSViewRepresentable {
    var isRecording: Bool
    var onCapture: (KeyChord) -> Void
    var onCancel: () -> Void
    
    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }
    
    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        nsView.setRecording(isRecording)
    }
    
    final class RecorderView: NSView {
        var onCapture: ((KeyChord) -> Void)?
        var onCancel: (() -> Void)?
        private var monitor: Any?
        
        override var acceptsFirstResponder: Bool { true }
        
        func setRecording(_ recording: Bool) {
            if recording {
                window?.makeFirstResponder(self)
                if monitor == nil {
                    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                        guard let self else { return event }
                        if event.keyCode == UInt16(kVK_Escape) {
                            self.onCancel?()
                            return nil
                        }
                        if let chord = KeyChord.from(event: event) {
                            self.onCapture?(chord)
                            return nil
                        }
                        return nil
                    }
                }
            } else if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
        
        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

#Preview {
    ShortcutsSettingsPane()
        .environment(DataStore())
        .frame(width: 520, height: 420)
}
