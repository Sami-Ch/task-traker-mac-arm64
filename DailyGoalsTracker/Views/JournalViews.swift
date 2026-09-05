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
    
    @FocusState private var isEditorFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            PeriodNavigationHeader(
                title: dateTitle,
                subtitle: fullDate,
                onPrevious: {
                    shiftDay(-1)
                },
                onNext: {
                    shiftDay(1)
                }
            )
            
            Divider()
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $state.draftText)
                    .font(.system(size: 16, weight: .regular))
                    .scrollContentBackground(.hidden)
                    .focusEffectDisabled()
                    .padding(16)
                    .focused($isEditorFocused)
                
                if state.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("How was this day?")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 21)
                        .padding(.top, 24)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            HStack {
                Text(statusLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Today") {
                    jumpToToday()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
                .opacity(isToday ? 0.3 : 1)
                .disabled(isToday)
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
        }
        .frame(minWidth: 420, minHeight: 420)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            state.draftText = dataStore.journalText(for: state.selectedDate)
            isEditorFocused = true
        }
        .onChange(of: state.selectedDate) { oldDate, newDate in
            dataStore.setJournal(state.draftText, for: oldDate)
            state.draftText = dataStore.journalText(for: newDate)
            isEditorFocused = true
        }
        .onChange(of: state.draftText) { _, newValue in
            dataStore.setJournal(newValue, for: state.selectedDate)
        }
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(state.selectedDate)
    }
    
    private var dateTitle: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(state.selectedDate) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(state.selectedDate) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: state.selectedDate)
    }
    
    private var fullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: state.selectedDate)
    }
    
    private var statusLabel: String {
        let count = state.draftText.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }.count
        if count == 0 { return "Autosaves as you type" }
        return "\(count) word\(count == 1 ? "" : "s") · autosaved"
    }
    
    private func shiftDay(_ delta: Int) {
        let base = Calendar.current.startOfDay(for: state.selectedDate)
        state.selectedDate = Calendar.current.date(byAdding: .day, value: delta, to: base) ?? state.selectedDate
    }
    
    private func jumpToToday() {
        state.selectedDate = Calendar.current.startOfDay(for: Date())
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
        .frame(width: 520, height: 640)
}
