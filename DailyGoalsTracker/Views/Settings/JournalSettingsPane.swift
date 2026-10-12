import AppKit
import SwiftUI

struct JournalSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    
    @State private var password = ""
    @State private var confirmation = ""
    @State private var currentPassword = ""
    @State private var errorMessage: String?
    @State private var mode: PasswordMode?
    @State private var pending: PendingChange?
    @State private var controlEpoch = 0
    
    private enum PasswordMode: String, Identifiable {
        case create = "Set Journal Password"
        case change = "Change Journal Password"
        case remove = "Remove Journal Password"
        case unlock = "Unlock Journal"
        var id: String { rawValue }
    }
    
    private enum PendingChange {
        case scope(JournalLockScope)
        case touchID(Bool)
    }
    
    var body: some View {
        Form {
            Section {
                Text("One password protects every secured day. It is never stored. If you forget it, those days cannot be read.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            Section("Password") {
                if dataStore.journalLock.hasPassword {
                    LabeledContent("Status") {
                        Text(dataStore.journalLock.isUnlocked ? "Unlocked for this session" : "Locked")
                            .foregroundStyle(.secondary)
                    }
                    Button("Change Password") { begin(.change) }
                    Button("Remove Password") { begin(.remove) }
                        .foregroundStyle(.red)
                } else {
                    Button("Set Password") { begin(.create) }
                }
            }
            
            Section("What to encrypt") {
                Picker("Scope", selection: scopeBinding) {
                    ForEach(JournalLockScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!dataStore.journalLock.hasPassword)
                .id(controlEpoch)
                
                Text(scopeHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if dataStore.journalLock.hasPassword && dataStore.journalLock.biometryAvailable {
                Section("Touch ID") {
                    Toggle("Unlock with Touch ID", isOn: touchIDBinding)
                        .id(controlEpoch)
                    Text("Touch ID uses the same key as the password. If fingerprints change, or you change the password, use the password and turn this on again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Auto-lock") {
                Picker("Lock after inactivity", selection: autoLockBinding) {
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("4 hours").tag(240)
                }
                Text("The journal also locks when its window closes. Default is 1 hour with no typing or clicking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Page") {
                Picker("Background", selection: paperBinding) {
                    ForEach(JournalPaper.allCases) { paper in
                        Text(paper.title).tag(paper)
                    }
                }
                if dataStore.settings.journalPaper == .custom {
                    ColorPicker("Color", selection: customColorBinding, supportsOpacity: false)
                }
                Text("Automatic is a soft paper color in light mode and the system background in dark mode. Change the text color from the journal toolbar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Shortcuts") {
                LabeledContent("Previous Day") {
                    Text(dataStore.settings.shortcuts.journalPreviousDay.displayString)
                        .font(.system(.body, design: .rounded).monospaced())
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Next Day") {
                    Text(dataStore.settings.shortcuts.journalNextDay.displayString)
                        .font(.system(.body, design: .rounded).monospaced())
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Insert Tasks") {
                    Text(dataStore.settings.shortcuts.insertJournalTasks.displayString)
                        .font(.system(.body, design: .rounded).monospaced())
                        .foregroundStyle(.secondary)
                }
                Text("Change these in Settings → Shortcuts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $mode, onDismiss: {
            pending = nil
        }) { mode in
            passwordSheet(mode)
        }
    }
    
    private var scopeHelp: String {
        switch dataStore.journalLock.scope {
        case .all:
            return "Every journal day is encrypted."
        case .selected:
            return "Only days you mark secure in the journal are encrypted. Other days stay readable."
        }
    }
    
    private var paperBinding: Binding<JournalPaper> {
        Binding(
            get: { dataStore.settings.journalPaper },
            set: { newValue in
                dataStore.updateSettings { $0.journalPaper = newValue }
            }
        )
    }
    
    private var customColorBinding: Binding<Color> {
        Binding(
            get: {
                if let rgb = dataStore.settings.journalPaperRGB {
                    return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
                }
                return Color(nsColor: JournalPageColors.warm)
            },
            set: { newValue in
                let resolved = NSColor(newValue).usingColorSpace(.sRGB) ?? NSColor(newValue)
                dataStore.updateSettings {
                    $0.journalPaperRGB = JournalRGB(
                        red: Double(resolved.redComponent),
                        green: Double(resolved.greenComponent),
                        blue: Double(resolved.blueComponent)
                    )
                }
            }
        )
    }
    
    private var scopeBinding: Binding<JournalLockScope> {
        Binding(
            get: { dataStore.journalLock.scope },
            set: { newValue in
                guard newValue != dataStore.journalLock.scope else { return }
                errorMessage = nil
                if dataStore.journalLock.hasPassword && !dataStore.journalLock.isUnlocked {
                    queue(.scope(newValue))
                    return
                }
                applyScope(newValue)
            }
        )
    }
    
    private var touchIDBinding: Binding<Bool> {
        Binding(
            get: { dataStore.journalLock.touchIDEnabled },
            set: { enabled in
                guard enabled != dataStore.journalLock.touchIDEnabled else { return }
                errorMessage = nil
                if !dataStore.journalLock.isUnlocked {
                    queue(.touchID(enabled))
                    return
                }
                applyTouchID(enabled)
            }
        )
    }
    
    private func queue(_ change: PendingChange) {
        pending = change
        controlEpoch += 1
        if dataStore.journalLock.touchIDEnabled {
            Task { await verifyWithTouchID() }
        } else {
            begin(.unlock)
        }
    }
    
    private func verifyWithTouchID() async {
        do {
            try await dataStore.unlockJournalWithTouchID(fresh: true)
            let change = pending
            pending = nil
            if let change { apply(change) }
        } catch JournalLockError.needsJournalPassword {
            begin(.unlock)
        } catch JournalLockError.biometryCancelled {
            pending = nil
        } catch {
            errorMessage = error.localizedDescription
            pending = nil
        }
    }
    
    private func apply(_ change: PendingChange) {
        switch change {
        case .scope(let scope):
            applyScope(scope)
        case .touchID(let enabled):
            applyTouchID(enabled)
        }
    }
    
    private func applyScope(_ scope: JournalLockScope) {
        do {
            try dataStore.setJournalScope(scope)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func applyTouchID(_ enabled: Bool) {
        Task {
            do {
                try await dataStore.setJournalTouchID(enabled)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private var autoLockBinding: Binding<Int> {
        Binding(
            get: { dataStore.settings.journalAutoLockMinutes },
            set: { minutes in
                dataStore.updateSettings { $0.journalAutoLockMinutes = minutes }
                dataStore.scheduleJournalAutoLock()
            }
        )
    }
    
    private func begin(_ mode: PasswordMode) {
        password = ""
        confirmation = ""
        currentPassword = ""
        errorMessage = nil
        self.mode = mode
    }
    
    private func passwordSheet(_ mode: PasswordMode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode.rawValue)
                .font(.headline)
            
            if mode == .change {
                SecureField("Current password", text: $currentPassword)
            }
            if mode == .unlock, let pendingPrompt {
                Text(pendingPrompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if mode == .remove || mode == .unlock {
                SecureField("Password", text: $currentPassword)
            }
            if mode == .create || mode == .change {
                SecureField(mode == .create ? "Password" : "New password", text: $password)
                SecureField("Confirm password", text: $confirmation)
            }
            
            Text("A forgotten password cannot recover encrypted days.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    pending = nil
                    self.mode = nil
                }
                Button(confirmTitle(mode)) { submit(mode) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
    
    private var pendingPrompt: String? {
        switch pending {
        case .touchID(true):
            return "Enter your journal password to turn on Touch ID."
        case .touchID(false):
            return "Enter your journal password to turn off Touch ID."
        case .scope:
            return "Enter your journal password to change what is encrypted."
        case nil:
            return nil
        }
    }
    
    private func confirmTitle(_ mode: PasswordMode) -> String {
        switch mode {
        case .remove: return "Remove"
        case .unlock: return "Unlock"
        case .create, .change: return "Save"
        }
    }
    
    private func submit(_ mode: PasswordMode) {
        errorMessage = nil
        do {
            switch mode {
            case .create:
                try dataStore.setJournalPassword(password, confirmation: confirmation)
            case .change:
                try dataStore.changeJournalPassword(from: currentPassword, to: password, confirmation: confirmation)
            case .remove:
                try dataStore.removeJournalPassword(currentPassword)
            case .unlock:
                try dataStore.unlockJournal(password: currentPassword)
            }
            let followUp = mode == .unlock ? pending : nil
            pending = nil
            self.mode = nil
            if let followUp {
                apply(followUp)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
