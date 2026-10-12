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

/// Shared date for the standalone journal window. The text view owns the open page.
@Observable
final class JournalWindowState {
    var selectedDate: Date = Date()
    /// Writes the open page before the window closes or the app quits.
    var flush: (() -> Void)?
    /// Set before the window is shown so the first appearance can insert the day's tasks.
    var pendingTaskTemplate = false
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
    @Environment(\.colorScheme) private var colorScheme
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
                    RichTextEditor(session: editor, paper: pagePaper, ink: pageInk)
                    
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
        .background(windowBackground)
        .onAppear {
            editor.persistHandler = { text, date in
                dataStore.setJournal(text, for: date)
            }
            editor.onCommandArrowDay = { delta in
                shiftDay(delta)
            }
            syncDayShortcutChords()
            state.flush = { editor.persistNow() }
            openDay(state.selectedDate, saving: nil)
            considerAutoPrompt()
            consumePendingTaskTemplate()
        }
        .onDisappear {
            editor.persistNow()
            state.flush = nil
        }
        .onChange(of: dataStore.settings.shortcuts) { _, _ in
            syncDayShortcutChords()
        }
        .background(JournalDayKeyboardShortcuts(
            previous: dataStore.settings.shortcuts.journalPreviousDay,
            next: dataStore.settings.shortcuts.journalNextDay,
            onPrevious: { shiftDay(-1) },
            onNext: { shiftDay(1) }
        ))
        .onChange(of: state.selectedDate) { oldDate, newDate in
            openDay(newDate, saving: oldDate)
            considerAutoPrompt()
        }
        .onReceive(NotificationCenter.default.publisher(for: .insertJournalTaskTemplate)) { _ in
            insertTaskTemplate()
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
                consumePendingTaskTemplate()
            }
        }
    }
    
    /// Move only after the open page is written. The save uses the day that was
    /// on screen, not the day being opened.
    private func shiftDay(_ delta: Int) {
        editor.persistNow()
        state.selectedDate = presentation.shiftedDay(state.selectedDate, by: delta)
    }
    
    private func syncDayShortcutChords() {
        let shortcuts = dataStore.settings.shortcuts
        editor.previousDayChord = shortcuts.journalPreviousDay
        editor.nextDayChord = shortcuts.journalNextDay
    }
    
    private func jumpToToday() {
        editor.persistNow()
        state.selectedDate = dataStore.logicalDate()
    }
    
    private func consumePendingTaskTemplate() {
        guard state.pendingTaskTemplate, !isDayLocked else { return }
        state.pendingTaskTemplate = false
        insertTaskTemplate()
    }
    
    private func insertTaskTemplate() {
        guard !isDayLocked else { return }
        editor.insertTaskTemplate(dataStore.journalTaskTemplate(for: state.selectedDate))
    }
    
    private func openDay(_ date: Date, saving previous: Date?) {
        if let previous, previous != date, dataStore.journal(for: previous)?.isSealed != true {
            editor.persistNow()
        }
        editor.boundDate = date
        let document = dataStore.journalAttributedString(for: date)
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
    
    private var pagePaper: NSColor {
        JournalPageColors.paper(
            for: dataStore.settings.journalPaper,
            custom: dataStore.settings.journalPaperRGB,
            scheme: colorScheme
        )
    }
    
    private var pageInk: NSColor {
        JournalPageColors.ink(for: pagePaper, choice: dataStore.settings.journalPaper, scheme: colorScheme)
    }
    
    /// Match the page only when the chrome text will still read on it.
    private var windowBackground: Color {
        let paperIsLight = JournalPageColors.isLight(pagePaper)
        let schemeIsLight = colorScheme == .light
        if paperIsLight == schemeIsLight {
            return Color(nsColor: pagePaper)
        }
        return Color(nsColor: .windowBackgroundColor)
    }
    
    private var chromeChip: Color {
        Color.primary.opacity(colorScheme == .light ? 0.08 : 0.05)
    }
    
    /// Quiet chrome text. System secondary is about 4:1 on white, under the usual reading size.
    private var chromeQuiet: Color {
        colorScheme == .light ? Color.black.opacity(0.62) : Color.white.opacity(0.72)
    }
    
    private var pageIsLight: Bool { JournalPageColors.isLight(pagePaper) }
    
    private var pagePrompt: Color {
        pageIsLight ? Color.black.opacity(0.78) : Color.white.opacity(0.88)
    }
    
    private var pageQuiet: Color {
        pageIsLight ? Color.black.opacity(0.62) : Color.white.opacity(0.78)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Button {
                shiftDay(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chromeQuiet)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(chromeChip))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Previous day (\(dataStore.settings.shortcuts.journalPreviousDay.displayString))")
            
            VStack(spacing: 2) {
                Text(presentation.relativeTitle(for: state.selectedDate, logicalToday: dataStore.logicalDate()))
                    .font(.system(size: 15, weight: .semibold))
                Text(presentation.dateSubtitle(for: state.selectedDate))
                    .font(.system(size: 11))
                    .foregroundStyle(chromeQuiet)
            }
            .frame(minWidth: 140)
            
            Button {
                shiftDay(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chromeQuiet)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(chromeChip))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Next day (\(dataStore.settings.shortcuts.journalNextDay.displayString))")
            
            Button {
                insertTaskTemplate()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Tasks")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(chromeChip, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(isDayLocked)
            .help(isDayLocked
                  ? "Unlock this day to add its tasks"
                  : "Add this day's tasks (\(dataStore.settings.shortcuts.insertJournalTasks.displayString))")
            
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
            .background(chromeChip, in: RoundedRectangle(cornerRadius: 6))
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
            .background(chromeChip, in: RoundedRectangle(cornerRadius: 6))
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
                    .foregroundStyle(pagePrompt)
                
                VStack(alignment: .leading, spacing: 8) {
                    hintRow("⌘B Bold", "⌘I Italic", "⌘U Underline")
                    hintRow("⌘⌥1 Heading", "⌘⇧8 Bullets", "⌘K Link")
                    hintRow("⌘; Insert date", "⌘⇧F Focus mode", "")
                }
                .font(.system(size: 11))
                .foregroundStyle(pageQuiet)
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
                    .background(chromeChip, in: Capsule())
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
            .foregroundStyle(chromeQuiet)
            
            Circle()
                .fill(Color.primary.opacity(0.28))
                .frame(width: 3, height: 3)
            
            // Character count
            HStack(spacing: 4) {
                Image(systemName: "character")
                    .font(.system(size: 10))
                Text("\(editor.characterCount) chars")
            }
            .font(.system(size: 11))
            .foregroundStyle(chromeQuiet)
            
            Circle()
                .fill(Color.primary.opacity(0.28))
                .frame(width: 3, height: 3)
            
            // Reading time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(readingTimeLabel)
            }
            .font(.system(size: 11))
            .foregroundStyle(chromeQuiet)
            
            Circle()
                .fill(Color.primary.opacity(0.28))
                .frame(width: 3, height: 3)
            
            saveStatus
            
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
                .foregroundStyle(dataStore.isLogicalToday(state.selectedDate) ? AnyShapeStyle(chromeQuiet) : AnyShapeStyle(Color.blue))
            }
            .buttonStyle(.plain)
            .disabled(dataStore.isLogicalToday(state.selectedDate))
        }
        .padding(.horizontal, 16)
        .frame(height: 32)
    }
    
    private var saveStatus: some View {
        HStack(spacing: 4) {
            switch editor.savePhase {
            case .saving:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                Text("Saving…")
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green.opacity(0.7))
                Text("Saved")
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.85))
                Text("Couldn't save")
                    .help(message)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(chromeQuiet)
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
                attributedString: editor.snapshot() ?? JournalRichText.defaultAttributedString(),
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
            JournalExporter.exportWord(
                attributedString: editor.snapshot() ?? JournalRichText.defaultAttributedString(),
                to: url
            )
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
            JournalExporter.exportMarkdown(
                attributedString: editor.snapshot() ?? JournalRichText.defaultAttributedString(),
                to: url
            )
        }
    }
}

// MARK: - Journal Exporter

enum JournalExporter {
    
    static func exportPDF(attributedString: NSAttributedString, date: Date, presentation: CalendarPresentation, to url: URL) {
        // Create a text view for printing
        let printView = NSTextView(usingTextLayoutManager: true)
        printView.frame = NSRect(x: 0, y: 0, width: 612 - 72, height: 792 - 72)
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
            let docData = try JournalTextLists.withPrintedMarkers(attributedString).data(
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

/// Local monitor so journal day shortcuts work when the editor is not first responder.
private struct JournalDayKeyboardShortcuts: View {
    let previous: KeyChord
    let next: KeyChord
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    @State private var monitor: Any?
    
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { install() }
            .onDisappear { remove() }
            .onChange(of: previous) { _, _ in install() }
            .onChange(of: next) { _, _ in install() }
    }
    
    private func install() {
        remove()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard NSApp.keyWindow?.title == "Journal" else { return event }
            // ⌘← and ⌘→ move the caret while typing. Day shortcuts apply only when a text view is not focused.
            if NSApp.keyWindow?.firstResponder is NSTextView { return event }
            if previous.matches(event) {
                onPrevious()
                return nil
            }
            if next.matches(event) {
                onNext()
                return nil
            }
            return event
        }
    }
    
    private func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
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
