import SwiftUI

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

/// Shared date and draft text for the standalone journal window.
@Observable
final class JournalWindowState {
    var selectedDate: Date = Date()
    var draftText: String = ""
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
    
    var body: some View {
        Button {
            openJournal(date)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: entry == nil ? "book.closed" : "book.closed.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("Journal")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer(minLength: 0)
                        Text(entry == nil ? "Write" : "Open")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.blue)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    
                    Text(entry?.preview ?? "How was this day?")
                        .font(.system(size: 12))
                        .foregroundStyle(entry == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
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
    
    @State private var editor = MarkdownEditingSession()
    @State private var showPreview = false
    
    private var presentation: CalendarPresentation {
        dataStore.calendarPresentation
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date navigation
            headerView
            
            Divider()
            
            // Toolbar area
            toolbarArea
            
            Divider()
            
            // Editor/Preview content
            ZStack(alignment: .topLeading) {
                if showPreview {
                    MarkdownPreview(text: state.draftText)
                        .transition(.opacity)
                } else {
                    MarkdownTextEditor(text: $state.draftText, session: editor)
                        .transition(.opacity)
                    
                    // Placeholder
                    if state.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        placeholderView
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.15), value: showPreview)
            
            Divider()
            
            // Status bar
            statusBar
        }
        .frame(minWidth: 520, minHeight: 500)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            state.draftText = dataStore.journalText(for: state.selectedDate)
        }
        .onChange(of: state.selectedDate) { oldDate, newDate in
            dataStore.setJournal(state.draftText, for: oldDate)
            state.draftText = dataStore.journalText(for: newDate)
            showPreview = false
        }
        .onChange(of: state.draftText) { _, newValue in
            dataStore.setJournal(newValue, for: state.selectedDate)
        }
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
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            
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
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Toolbar
    
    private var toolbarArea: some View {
        HStack(spacing: 0) {
            if !showPreview {
                MarkdownToolbar(session: editor)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "eye")
                        .font(.system(size: 11))
                    Text("Preview")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                Spacer()
            }
            
            // Mode toggle
            modeToggle
        }
        .frame(height: 40)
        .background(Color.primary.opacity(0.02))
    }
    
    private var modeToggle: some View {
        HStack(spacing: 2) {
            toggleButton("pencil", label: "Edit", isActive: !showPreview) {
                showPreview = false
            }
            toggleButton("eye", label: "Preview", isActive: showPreview) {
                showPreview = true
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .padding(.trailing, 10)
    }
    
    private func toggleButton(_ icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.orange.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(isActive ? Color.orange : Color.secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Placeholder
    
    private var placeholderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How was this day?")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tertiary)
            
            HStack(spacing: 16) {
                hintPill("**bold**", icon: "bold")
                hintPill("*italic*", icon: "italic")
                hintPill("==highlight==", icon: "highlighter")
            }
            .font(.system(size: 11))
            .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .allowsHitTesting(false)
    }
    
    private func hintPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack(spacing: 12) {
            // Word count
            HStack(spacing: 4) {
                Image(systemName: "text.word.spacing")
                    .font(.system(size: 10))
                Text(wordCountLabel)
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
    
    // MARK: - Helpers
    
    private func shiftDay(_ delta: Int) {
        state.selectedDate = presentation.shiftedDay(state.selectedDate, by: delta)
    }
    
    private func jumpToToday() {
        state.selectedDate = dataStore.logicalDate()
    }
    
    private var wordCountLabel: String {
        let count = state.draftText.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }.count
        return "\(count) word\(count == 1 ? "" : "s")"
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
        .frame(width: 560, height: 680)
}
