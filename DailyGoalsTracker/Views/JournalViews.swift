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
    @State private var sidebarQuery = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var renamingDayID: String?
    @State private var renameDraft = ""
    
    private var isDayLocked: Bool {
        dataStore.journal(for: state.selectedDate)?.isSealed == true
    }
    
    private var presentation: CalendarPresentation {
        dataStore.calendarPresentation
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            journalSidebar
        } detail: {
            journalPage
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 860, minHeight: 520)
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
            finishRename(save: true)
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
            if let renaming = renamingDayID, renaming != GoalEntry.dateString(from: newDate) {
                finishRename(save: true)
            }
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
            } else {
                renamingDayID = nil
            }
        }
    }
    
    private var journalPage: some View {
        VStack(spacing: 0) {
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
        .background(windowBackground)
        .overlayPreferenceValue(ToolbarTipKey.self) { tip in
            GeometryReader { proxy in
                if let tip {
                    let rect = proxy[tip.bounds]
                    let x = min(max(rect.midX, 90), max(90, proxy.size.width - 90))
                    let y = max(14, rect.minY - 18)
                    Text(tip.text)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: 280)
                        .fixedSize(horizontal: false, vertical: true)
                        .background {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.22), radius: 6, y: 2)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
                        }
                        .position(x: x, y: y)
                        .allowsHitTesting(false)
                }
            }
            .allowsHitTesting(false)
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
    
    private func finishRename(save: Bool, text: String? = nil) {
        guard let id = renamingDayID, let date = GoalEntry.date(from: id) else {
            renamingDayID = nil
            editor.suspendEditorFocus = false
            return
        }
        renamingDayID = nil
        editor.suspendEditorFocus = false
        guard save else { return }
        let draft = (text ?? renameDraft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft != dataStore.journalTitle(for: date) else { return }
        do {
            try dataStore.setJournalTitle(draft, for: date)
        } catch {
            unlockError = error.localizedDescription
        }
    }
    
    private func beginRename(_ day: JournalDayListItem) {
        guard renamingDayID != day.id else { return }
        if renamingDayID != nil {
            finishRename(save: true)
        }
        editor.suspendEditorFocus = true
        columnVisibility = .all
        renameDraft = day.title
        renamingDayID = day.id
    }
    
    // MARK: - Sidebar
    
    private var selectedDayID: Binding<String?> {
        Binding(
            get: { GoalEntry.dateString(from: state.selectedDate) },
            set: { newValue in
                guard let newValue, let date = GoalEntry.date(from: newValue) else { return }
                guard !Calendar.current.isDate(date, inSameDayAs: state.selectedDate) else { return }
                state.selectedDate = date
            }
        )
    }
    
    private var journalSidebar: some View {
        let groups = filteredDayGroups
        return List(selection: selectedDayID) {
            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.days) { day in
                        dayRow(day)
                            .tag(day.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 44)
        .overlay {
            if groups.isEmpty, !trimmedQuery.isEmpty {
                ContentUnavailableView.search(text: trimmedQuery)
            }
        }
        .onKeyPress(.return) {
            guard renamingDayID == nil, let day = selectedDayItem else { return .ignored }
            // The key is still in flight. Starting the field now would commit on that same Return.
            DispatchQueue.main.async { beginRename(day) }
            return .handled
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SidebarSearchField(text: $sidebarQuery, prompt: "Search titles and entries")
                .frame(height: 28)
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarFooter
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
    }
    
    private var sidebarFooter: some View {
        let written = dataStore.journalDayList().filter { $0.sealed || $0.wordCount > 0 }.count
        return VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Text(written == 1 ? "1 entry" : "\(written) entries")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
                Button("Today", action: jumpToToday)
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .medium))
                    .disabled(Calendar.current.isDate(state.selectedDate, inSameDayAs: dataStore.logicalDate()))
                    .help("Go to today")
            }
            .padding(.horizontal, 14)
            .frame(height: 30)
        }
    }
    
    private var selectedDayItem: JournalDayListItem? {
        let key = GoalEntry.dateString(from: state.selectedDate)
        return dataStore.journalDayList(including: state.selectedDate).first { $0.id == key }
    }
    
    private func dayRow(_ day: JournalDayListItem) -> some View {
        let today = dataStore.logicalDate()
        let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
        let content = sidebarRowText(for: day, today: today)
        let isRenaming = renamingDayID == day.id
        return dayRowLabel(day, isToday: isToday, content: content)
            .overlay {
                if !isRenaming {
                    SidebarRowClicker(
                        canRename: true,
                        canRemoveTitle: !day.title.isEmpty,
                        onSingle: { state.selectedDate = day.date },
                        onDouble: { beginRename(day); state.selectedDate = day.date },
                        onRemoveTitle: { try? dataStore.setJournalTitle("", for: day.date) }
                    )
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(presentation.dateSubtitle(for: day.date)), \(content.heading)")
            .accessibilityHint(day.sealed ? "Writing is locked. Double-click or press Return to rename." : "Double-click or press Return to rename")
            .accessibilityAction(named: "Rename") { beginRename(day) }
    }
    
    private func dayRowLabel(_ day: JournalDayListItem, isToday: Bool, content: SidebarRowText) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 0) {
                Text(presentation.weekdayName(for: day.date, style: .chip).uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(presentation.dayNumber(for: day.date))
                    .font(.system(size: 17, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isToday ? Color.accentColor : Color.primary)
                    .monospacedDigit()
            }
            .frame(width: 34)
            
            VStack(alignment: .leading, spacing: 1) {
                if renamingDayID == day.id {
                    SidebarRenameField(
                        text: renameDraft,
                        placeholder: "Add a title",
                        onCommit: { finishRename(save: true, text: $0) },
                        onCancel: { finishRename(save: false) }
                    )
                    .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                } else {
                    Text(content.heading)
                        .font(.system(size: 13, weight: content.headingIsTitle ? .semibold : .regular))
                        .foregroundStyle(content.headingIsQuiet ? Color.secondary : Color.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                HStack(spacing: 4) {
                    if day.sealed {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    Text(content.detail)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    
    private struct SidebarRowText {
        var heading: String
        var headingIsTitle: Bool
        var headingIsQuiet: Bool
        var detail: String
    }
    
    /// A title leads when there is one. Otherwise the first line of writing stands in, the way Notes names a note.
    private func sidebarRowText(for day: JournalDayListItem, today: Date) -> SidebarRowText {
        let relative = presentation.relativeTitle(for: day.date, logicalToday: today)
        if day.sealed {
            if !day.title.isEmpty {
                return SidebarRowText(heading: day.title, headingIsTitle: true, headingIsQuiet: false, detail: "Locked")
            }
            return SidebarRowText(heading: relative, headingIsTitle: false, headingIsQuiet: false, detail: "Locked")
        }
        let preview = day.preview
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        let words = day.wordCount == 1 ? "1 word" : "\(day.wordCount) words"
        if !day.title.isEmpty {
            return SidebarRowText(
                heading: day.title,
                headingIsTitle: true,
                headingIsQuiet: false,
                detail: preview.isEmpty ? relative : preview
            )
        }
        if !preview.isEmpty {
            return SidebarRowText(heading: preview, headingIsTitle: false, headingIsQuiet: false, detail: "\(relative) · \(words)")
        }
        return SidebarRowText(heading: relative, headingIsTitle: false, headingIsQuiet: true, detail: "No entry yet")
    }
    
    private var trimmedQuery: String {
        sidebarQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private struct JournalDayGroup: Identifiable {
        var id: String
        var title: String
        var days: [JournalDayListItem]
    }
    
    private var filteredDayGroups: [JournalDayGroup] {
        let query = trimmedQuery
        let today = dataStore.logicalDate()
        let days = dataStore.journalDayList(including: state.selectedDate).filter { day in
            guard !query.isEmpty else { return true }
            let fields = [
                day.title,
                day.preview,
                presentation.relativeTitle(for: day.date, logicalToday: today),
                presentation.dateSubtitle(for: day.date),
            ]
            return fields.contains { $0.localizedStandardContains(query) }
        }
        let calendar = Calendar.current
        var order: [String] = []
        var buckets: [String: (start: Date, days: [JournalDayListItem])] = [:]
        for day in days {
            let parts = calendar.dateComponents([.year, .month], from: day.date)
            let key = "\(parts.year ?? 0)-\(parts.month ?? 0)"
            let start = calendar.date(from: parts) ?? day.date
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = (start, [])
            }
            buckets[key]?.days.append(day)
        }
        return order.compactMap { key in
            guard let bucket = buckets[key] else { return nil }
            return JournalDayGroup(
                id: key,
                title: presentation.monthTitle(for: bucket.start),
                days: bucket.days
            )
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Button {
                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chromeQuiet)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(chromeChip))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(columnVisibility == .detailOnly ? "Show days" : "Hide days")
            
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
                let pageTitle = dataStore.journalTitle(for: state.selectedDate)
                if !pageTitle.isEmpty {
                    Text(pageTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(presentation.dateSubtitle(for: state.selectedDate))
                        .font(.system(size: 11))
                        .foregroundStyle(chromeQuiet)
                } else {
                    Text(presentation.relativeTitle(for: state.selectedDate, logicalToday: dataStore.logicalDate()))
                        .font(.system(size: 15, weight: .semibold))
                    Text(presentation.dateSubtitle(for: state.selectedDate))
                        .font(.system(size: 11))
                        .foregroundStyle(chromeQuiet)
                }
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
            let lockedTitle = dataStore.journalTitle(for: state.selectedDate)
            if !lockedTitle.isEmpty {
                Text(lockedTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            Text(lockedTitle.isEmpty ? "This day is encrypted" : "This day's writing is encrypted")
                .font(.system(size: lockedTitle.isEmpty ? 16 : 13, weight: lockedTitle.isEmpty ? .semibold : .regular))
                .foregroundStyle(lockedTitle.isEmpty ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
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
                    hintRow("⌘; Insert date", "⌘D Next match", "⌘⇧F Focus")
                    hintRow("⌘⌥← Previous day", "⌘⌥→ Next day", "")
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

/// Local monitor so ⌘⌥← / ⌘⌥→ change the journal day even while the caret is in the text.
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

// MARK: - Sidebar fields

/// The system search field. `.searchable` needs a window toolbar, which the journal window does not have.
private struct SidebarSearchField: NSViewRepresentable {
    @Binding var text: String
    var prompt: String
    
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    
    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.controlSize = .regular
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = false
        field.target = context.coordinator
        field.action = #selector(Coordinator.search(_:))
        field.delegate = context.coordinator
        return field
    }
    
    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text {
            field.stringValue = text
        }
    }
    
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        
        @objc func search(_ sender: NSSearchField) {
            text.wrappedValue = sender.stringValue
        }
        
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.cancelOperation(_:)), !control.stringValue.isEmpty else { return false }
            control.stringValue = ""
            text.wrappedValue = ""
            return true
        }
    }
}

/// Left click opens the day. The second click of a double-click renames it.
/// A SwiftUI button only reports one click, so the click count has to be read from the event.
private struct SidebarRowClicker: NSViewRepresentable {
    var canRename: Bool
    var canRemoveTitle: Bool
    var onSingle: () -> Void
    var onDouble: () -> Void
    var onRemoveTitle: () -> Void
    
    func makeNSView(context: Context) -> Clicker { Clicker() }
    
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Clicker, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 220, height: proposal.height ?? 44)
    }
    
    func updateNSView(_ view: Clicker, context: Context) {
        view.canRename = canRename
        view.canRemoveTitle = canRemoveTitle
        view.onSingle = onSingle
        view.onDouble = onDouble
        view.onRemoveTitle = onRemoveTitle
    }
    
    final class Clicker: NSView {
        var canRename = true
        var canRemoveTitle = false
        var onSingle: () -> Void = {}
        var onDouble: () -> Void = {}
        var onRemoveTitle: () -> Void = {}
        
        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(point) ? self : nil
        }
        
        override func mouseDown(with event: NSEvent) {
            if event.clickCount >= 2, canRename {
                onDouble()
            } else {
                onSingle()
            }
        }
        
        override func rightMouseDown(with event: NSEvent) {
            let menu = NSMenu()
            let rename = menu.addItem(withTitle: "Rename…", action: #selector(rename(_:)), keyEquivalent: "")
            rename.target = self
            rename.isEnabled = canRename
            if canRemoveTitle {
                let remove = menu.addItem(withTitle: "Remove Title", action: #selector(removeTitle(_:)), keyEquivalent: "")
                remove.target = self
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
        
        @objc private func rename(_ sender: Any?) { onDouble() }
        @objc private func removeTitle(_ sender: Any?) { onRemoveTitle() }
    }
}

/// Inline rename in the Finder manner: the name is selected on entry, Return keeps it, Escape restores it,
/// and clicking elsewhere keeps the edit. Keystrokes stay in the field so the list does not rebuild mid-edit.
private struct SidebarRenameField: NSViewRepresentable {
    var text: String
    var placeholder: String
    var onCommit: (String) -> Void
    var onCancel: () -> Void
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeNSView(context: Context) -> RenameTextField {
        let field = RenameTextField(string: text)
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: 13, weight: .semibold)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = true
        field.backgroundColor = .textBackgroundColor
        field.focusRingType = .exterior
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        context.coordinator.field = field
        return field
    }
    
    func updateNSView(_ field: RenameTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.field = field
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
    }
    
    final class RenameTextField: NSTextField {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            focus(attempts: 8)
        }
        
        private func focus(attempts: Int) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let window = self.window else {
                    if attempts > 1 { self.focus(attempts: attempts - 1) }
                    return
                }
                let editor = window.firstResponder
                if editor === self.currentEditor() || editor === self {
                    self.currentEditor()?.selectAll(nil)
                    return
                }
                if window.makeFirstResponder(self) {
                    self.currentEditor()?.selectAll(nil)
                } else if attempts > 1 {
                    self.focus(attempts: attempts - 1)
                }
            }
        }
    }
    
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SidebarRenameField
        weak var field: NSTextField?
        private var finished = false
        private var beganEditing = false
        
        init(_ parent: SidebarRenameField) { self.parent = parent }
        
        func controlTextDidBeginEditing(_ notification: Notification) {
            beganEditing = true
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                finish(commit: true, value: control.stringValue)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                finish(commit: false, value: control.stringValue)
                return true
            default:
                return false
            }
        }
        
        func controlTextDidEndEditing(_ notification: Notification) {
            guard beganEditing, let field else { return }
            finish(commit: true, value: field.stringValue)
        }
        
        private func finish(commit: Bool, value: String) {
            guard !finished else { return }
            finished = true
            let parent = parent
            DispatchQueue.main.async {
                commit ? parent.onCommit(value) : parent.onCancel()
            }
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
