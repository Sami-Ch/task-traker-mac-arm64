import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Open journal window

private struct OpenJournalActionKey: EnvironmentKey {
    static let defaultValue = OpenJournalAction { _ in }
}

extension EnvironmentValues {
    var openJournal: OpenJournalAction {
        get { self[OpenJournalActionKey.self] }
        set { self[OpenJournalActionKey.self] = newValue }
    }
}

struct OpenJournalAction {
    let action: (Date) -> Void
    
    func callAsFunction(_ date: Date) {
        action(date)
    }
}

/// Shared date and attributed text for the standalone journal window.
@Observable
final class JournalWindowState {
    var selectedDate: Date = Date()
    var attributedText: NSAttributedString = JournalRichText.defaultAttributedString()
    
    var plainText: String {
        attributedText.string
    }
    
    var isEmpty: Bool {
        plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Popover preview

/// Compact read-only card. Tapping opens the writing window for that day.
struct JournalPreviewCard: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.openJournal) private var openJournal
    let date: Date
    
    private var entry: JournalEntry? {
        dataStore.journal(for: date)
    }
    
    private var isLocked: Bool {
        entry?.isSealed == true
    }
    
    var body: some View {
        Button {
            openJournal(date)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isLocked ? "lock.fill" : (entry == nil ? "book.closed" : "book.closed.fill"))
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("Journal")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer(minLength: 0)
                        Text(isLocked ? "Locked" : (entry == nil ? "Write" : "Open"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.blue)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    
                    Text(isLocked ? "This day is encrypted." : (entry?.preview ?? "How was this day?"))
                        .font(.system(size: 12))
                        .foregroundStyle(entry == nil || isLocked ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.orange.opacity(0.18), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .help("Open this day's journal in a window")
    }
}

// MARK: - Writing window

struct JournalWindowView: View {
    @Environment(DataStore.self) private var dataStore
    @Bindable var state: JournalWindowState
    
    @State private var editor = RichTextEditingSession()
    @State private var unlockPassword = ""
    @State private var unlockError: String?
    @State private var showPasswordSheet = false
    @State private var pendingSecurityChange: Bool?
    @State private var showPasswordHint = false
    @State private var autoPromptedDay: String?
    
    private var isDayLocked: Bool {
        dataStore.journal(for: state.selectedDate)?.isSealed == true
    }
    
    private var presentation: CalendarPresentation {
        dataStore.calendarPresentation
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date navigation
            headerView
            
            Divider()
            
            if isDayLocked {
                lockScreen
            } else {
                RichTextToolbar(session: editor)
                    .background(Color.primary.opacity(0.02))
                
                Divider()
                
                ZStack(alignment: .topLeading) {
                    RichTextEditor(session: editor, document: state.attributedText)
                    
                    if editor.isEmpty {
                        placeholderView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            statusBar
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            editor.onLiveUpdate = { text in
                state.attributedText = text
            }
            editor.persistHandler = { text, date in
                dataStore.setJournal(text, for: date)
            }
            openDay(state.selectedDate, saving: nil)
            considerAutoPrompt()
        }
        .onChange(of: state.selectedDate) { oldDate, newDate in
            openDay(newDate, saving: oldDate)
            considerAutoPrompt()
        }
        .sheet(isPresented: $showPasswordSheet) {
            passwordSheet
        }
        .alert("Journal password", isPresented: $showPasswordHint) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Set a journal password in Settings first.")
        }
        .onChange(of: dataStore.journalLock.isUnlocked) { _, unlocked in
            if unlocked {
                unlockPassword = ""
                unlockError = nil
            }
        }
    }
    
    /// Move only after the open page is written. The save uses the day that was
    /// on screen, not the day being opened.
    private func shiftDay(_ delta: Int) {
        editor.persistNow()
        state.selectedDate = presentation.shiftedDay(state.selectedDate, by: delta)
    }
    
    private func jumpToToday() {
        editor.persistNow()
        state.selectedDate = dataStore.logicalDate()
    }
    
    private func openDay(_ date: Date, saving previous: Date?) {
        if let previous, previous != date, dataStore.journal(for: previous)?.isSealed != true {
            editor.cancelPendingPersist()
            if let snap = editor.snapshot() {
                dataStore.setJournal(snap, for: previous)
            }
        }
        editor.boundDate = date
        let document = dataStore.journalAttributedString(for: date)
        state.attributedText = document
        editor.loadDocument(document)
    }
    
    /// The system prompt opens by itself the first time a sealed day is shown.
    /// Cancel leaves the Unlock button; moving to another sealed day asks again.
    private func considerAutoPrompt() {
        guard isDayLocked, !dataStore.journalLock.isUnlocked, !showPasswordSheet else { return }
        let key = GoalEntry.dateString(from: state.selectedDate)
        guard autoPromptedDay != key else { return }
        autoPromptedDay = key
        requestUnlock(fresh: false, then: nil)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Button {
                shiftDay(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Previous day")
            
            VStack(spacing: 2) {
                Text(presentation.relativeTitle(for: state.selectedDate, logicalToday: dataStore.logicalDate()))
                    .font(.system(size: 15, weight: .semibold))
                Text(presentation.dateSubtitle(for: state.selectedDate))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 140)
            
            Button {
                shiftDay(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Next day")
            
            Spacer()
            
            if dataStore.journalLock.scope != .all {
                securityButton
            }
            exportMenu
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    
    private var securityButton: some View {
        Button {
            toggleSecurity()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: currentDayIsSecure ? "lock.fill" : "lock.open")
                    .font(.system(size: 11, weight: .semibold))
                Text(currentDayIsSecure ? "Secured" : "Secure this day")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(securityHelp)
    }
    
    private var currentDayIsSecure: Bool {
        dataStore.journal(for: state.selectedDate)?.markedSecure == true
    }
    
    private var securityHelp: String {
        if !dataStore.journalLock.hasPassword {
            return "Set a journal password in Settings first"
        }
        if dataStore.journalLock.scope == .all {
            return "Every day is encrypted"
        }
        return currentDayIsSecure ? "Remove security after verification" : "Encrypt this day"
    }
    
    private func toggleSecurity() {
        unlockError = nil
        guard dataStore.journalLock.hasPassword else {
            showPasswordHint = true
            return
        }
        editor.persistNow()
        if currentDayIsSecure {
            requestUnlock(fresh: true, then: false)
            return
        }
        if dataStore.journalLock.isUnlocked {
            applySecurity(true)
            return
        }
        requestUnlock(fresh: false, then: true)
    }
    
    private func applySecurity(_ secure: Bool) {
        do {
            try dataStore.setDaySecure(state.selectedDate, secure: secure)
            if !secure {
                openDay(state.selectedDate, saving: nil)
            }
        } catch {
            unlockError = error.localizedDescription
        }
    }
    
    /// System Touch ID prompt, then one password field only if the user asks for it.
    private func requestUnlock(fresh: Bool, then secure: Bool?) {
        pendingSecurityChange = secure
        unlockError = nil
        guard dataStore.journalLock.touchIDEnabled else {
            unlockPassword = ""
            showPasswordSheet = true
            return
        }
        Task {
            do {
                try await dataStore.unlockJournalWithTouchID(fresh: fresh)
                finishUnlock()
            } catch JournalLockError.needsJournalPassword {
                unlockPassword = ""
                showPasswordSheet = true
            } catch JournalLockError.biometryCancelled {
                pendingSecurityChange = nil
            } catch {
                unlockError = error.localizedDescription
                pendingSecurityChange = nil
            }
        }
    }
    
    private func finishUnlock() {
        let change = pendingSecurityChange
        showPasswordSheet = false
        pendingSecurityChange = nil
        unlockPassword = ""
        if let change {
            applySecurity(change)
        } else {
            openDay(state.selectedDate, saving: nil)
        }
    }
    
    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("This day is encrypted")
                .font(.system(size: 16, weight: .semibold))
            Button("Unlock") {
                requestUnlock(fresh: false, then: nil)
            }
            .keyboardShortcut(.defaultAction)
            
            if let unlockError {
                Text(unlockError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var passwordSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Journal password")
                .font(.headline)
            SecureField("Password", text: $unlockPassword)
                .textFieldStyle(.roundedBorder)
                .onSubmit { submitPassword() }
            if let unlockError {
                Text(unlockError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    showPasswordSheet = false
                    pendingSecurityChange = nil
                    unlockPassword = ""
                    unlockError = nil
                }
                Button("Unlock") { submitPassword() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
    
    private func submitPassword() {
        unlockError = nil
        do {
            try dataStore.unlockJournal(password: unlockPassword)
            finishUnlock()
        } catch {
            unlockError = error.localizedDescription
        }
    }
    
    private var exportMenu: some View {
        Menu {
            Button("Export as PDF…") { exportPDF() }
            Button("Export as Word (.docx)…") { exportWord() }
            Button("Export as Markdown…") { exportMarkdown() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                Text("Export")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(editor.isEmpty || isDayLocked)
        .help("Export this day")
    }
    
    // MARK: - Placeholder
    
    private var placeholderView: some View {
        GeometryReader { geo in
            let side = max(48, (geo.size.width - 680) / 2)
            VStack(alignment: .leading, spacing: 12) {
                Text("How was this day?")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.tertiary)
                
                VStack(alignment: .leading, spacing: 8) {
                    hintRow("⌘B Bold", "⌘I Italic", "⌘U Underline")
                    hintRow("⌘⌥1 Heading", "⌘⇧8 Bullets", "⌘K Link")
                    hintRow("⌘; Insert date", "⌘⇧F Focus mode", "")
                }
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
            }
            .padding(.leading, side + 4)
            .padding(.top, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }
    
    private func hintRow(_ items: String...) -> some View {
        HStack(spacing: 16) {
            ForEach(items.filter { !$0.isEmpty }, id: \.self) { item in
                Text(item)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.04), in: Capsule())
            }
        }
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack(spacing: 12) {
            // Word count
            HStack(spacing: 4) {
                Image(systemName: "text.word.spacing")
                    .font(.system(size: 10))
                if let selCount = editor.selectionWordCount {
                    Text("\(selCount) of \(editor.wordCount) words")
                } else {
                    Text("\(editor.wordCount) words")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            
            Circle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 3, height: 3)
            
            // Character count
            HStack(spacing: 4) {
                Image(systemName: "character")
                    .font(.system(size: 10))
                Text("\(editor.characterCount) chars")
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            
            Circle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 3, height: 3)
            
            // Reading time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(readingTimeLabel)
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            
            Circle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 3, height: 3)
            
            // Autosave indicator
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green.opacity(0.7))
                Text("Autosaved")
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            
            Spacer()
            
            // Today button
            Button {
                jumpToToday()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("Today")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(dataStore.isLogicalToday(state.selectedDate) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.blue))
            }
            .buttonStyle(.plain)
            .disabled(dataStore.isLogicalToday(state.selectedDate))
        }
        .padding(.horizontal, 16)
        .frame(height: 32)
    }
    
    private var readingTimeLabel: String {
        let minutes = max(1, (editor.wordCount + 100) / 200)
        return "\(minutes) min read"
    }
    
    // MARK: - Export Functions
    
    private func suggestedFilename(extension ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Journal \(formatter.string(from: state.selectedDate)).\(ext)"
    }
    
    private func exportPDF() {
        editor.persistNow()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedFilename(extension: "pdf")
        panel.title = "Export Journal as PDF"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            JournalExporter.exportPDF(
                attributedString: state.attributedText,
                date: state.selectedDate,
                presentation: presentation,
                to: url
            )
        }
    }
    
    private func exportWord() {
        editor.persistNow()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
        panel.nameFieldStringValue = suggestedFilename(extension: "docx")
        panel.title = "Export Journal as Word Document"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            JournalExporter.exportWord(attributedString: state.attributedText, to: url)
        }
    }
    
    private func exportMarkdown() {
        editor.persistNow()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = suggestedFilename(extension: "md")
        panel.title = "Export Journal as Markdown"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            JournalExporter.exportMarkdown(attributedString: state.attributedText, to: url)
        }
    }
}

// MARK: - Journal Exporter

enum JournalExporter {
    
    static func exportPDF(attributedString: NSAttributedString, date: Date, presentation: CalendarPresentation, to url: URL) {
        // Create a text view for printing
        let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612 - 72, height: 792 - 72)) // US Letter with margins
        printView.textStorage?.setAttributedString(attributedString)
        printView.backgroundColor = .white
        
        // Add title
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let titleString = formatter.string(from: date)
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.textColor
        ]
        let titleAttr = NSMutableAttributedString(string: titleString + "\n\n", attributes: titleAttrs)
        titleAttr.append(attributedString)
        printView.textStorage?.setAttributedString(titleAttr)
        
        // Configure print info
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        
        // Set up for PDF
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobDisposition] = NSPrintInfo.JobDisposition.save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        
        let printOp = NSPrintOperation(view: printView, printInfo: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = true
        printOp.run()
    }
    
    static func exportWord(attributedString: NSAttributedString, to url: URL) {
        do {
            let docData = try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
            )
            try docData.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    static func exportMarkdown(attributedString: NSAttributedString, to url: URL) {
        let markdown = JournalRichText.toMarkdown(attributedString)
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

#Preview("Journal Card") {
    JournalPreviewCard(date: Date())
        .environment(DataStore())
        .frame(width: 400)
}

#Preview("Journal Window") {
    JournalWindowView(state: JournalWindowState())
        .environment(DataStore())
        .frame(width: 700, height: 680)
}
