import SwiftUI

struct JournalSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    
    @State private var password = ""
    @State private var confirmation = ""
    @State private var currentPassword = ""
    @State private var errorMessage: String?
    @State private var mode: PasswordMode?
    
    private enum PasswordMode: String, Identifiable {
        case create = "Set Journal Password"
        case change = "Change Journal Password"
        case remove = "Remove Journal Password"
        case unlock = "Unlock Journal"
        var id: String { rawValue }
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
                .disabled(!dataStore.journalLock.hasPassword || !dataStore.journalLock.isUnlocked)
                
                Text(scopeHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if dataStore.journalLock.hasPassword && !dataStore.journalLock.isUnlocked {
                    Button("Unlock to Change Scope") { begin(.unlock) }
                }
            }
            
            if dataStore.journalLock.hasPassword && dataStore.journalLock.biometryAvailable {
                Section("Touch ID") {
                    Toggle("Unlock with Touch ID", isOn: touchIDBinding)
                        .disabled(!dataStore.journalLock.isUnlocked)
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
            
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $mode) { mode in
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
    
    private var scopeBinding: Binding<JournalLockScope> {
        Binding(
            get: { dataStore.journalLock.scope },
            set: { newValue in
                errorMessage = nil
                do {
                    try dataStore.setJournalScope(newValue)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
    }
    
    private var touchIDBinding: Binding<Bool> {
        Binding(
            get: { dataStore.journalLock.touchIDEnabled },
            set: { enabled in
                errorMessage = nil
                Task {
                    do {
                        try await dataStore.setJournalTouchID(enabled)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        )
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
                Button("Cancel") { self.mode = nil }
                Button(mode == .remove ? "Remove" : "Save") { submit(mode) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
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
            self.mode = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
