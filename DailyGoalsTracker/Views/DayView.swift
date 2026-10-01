import SwiftUI

/// Daily goals view with progress ring and goal list
struct DayView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(SettingsRouter.self) private var settingsRouter
    @Binding var selectedDate: Date
    
    @State private var showingOneOff = false
    @State private var editingOneOff: Goal?
    
    private var presentation: CalendarPresentation {
        dataStore.calendarPresentation
    }
    
    private var summary: DailySummary {
        dataStore.getDailySummary(for: selectedDate)
    }
    
    private var dayGoals: (tracked: [Goal], skipped: [Goal]) {
        dataStore.goalsForDay(selectedDate)
    }
    
    private var isToday: Bool {
        dataStore.isLogicalToday(selectedDate)
    }
    
    private var isHistory: Bool {
        dataStore.isMembershipFrozen(on: selectedDate)
    }
    
    private var addableGoals: [Goal] {
        dataStore.goalsAvailableToAdd(on: selectedDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PeriodNavigationHeader(
                title: presentation.relativeTitle(for: selectedDate, logicalToday: dataStore.logicalDate()),
                subtitle: isToday && dataStore.settings.calendarDisplay == .gregorian ? nil : presentation.dateSubtitle(for: selectedDate),
                onPrevious: {
                    selectedDate = presentation.shiftedDay(selectedDate, by: -1)
                },
                onNext: {
                    selectedDate = presentation.shiftedDay(selectedDate, by: 1)
                }
            )
            
            Divider().padding(.horizontal)
            
            DayModePicker(date: selectedDate)
            
            NextPrayerBanner()
            
            AppTimeLimitBanner()
            
            Divider().padding(.horizontal)
            
            HStack(spacing: 8) {
                MiniProgressRing(progress: summary.completionPercentage, size: 16)
                Text("\(Int(summary.completionPercentage * 100))%")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                if summary.isSpecialDay {
                    Image(systemName: summary.dayMode.icon)
                        .font(.caption)
                        .foregroundStyle(summary.dayMode.color)
                }
                HStack(spacing: 10) {
                    labeledStat(count: summary.doneCount, label: "Done", color: .green)
                    labeledStat(count: summary.partialCount, label: "Part", color: .orange)
                    labeledStat(count: summary.notDoneCount, label: "Miss", color: .red)
                }
                Spacer(minLength: 0)
                if isHistory {
                    Text("History")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .help("This day's list is saved. You can still add or remove tasks; the weekly template will not rewrite it.")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: SummaryStrip.height)
            
            goalRows
            
            Divider().padding(.horizontal)
            
            JournalPreviewCard(date: selectedDate)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showingOneOff) {
            OneOffTaskSheet(date: selectedDate)
                .frame(width: 360, height: 320)
        }
        .sheet(item: $editingOneOff) { goal in
            OneOffTaskSheet(date: selectedDate, existing: goal)
                .frame(width: 360, height: 320)
        }
    }
    
    private var goalRows: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if isToday {
                    UsageGoalsSection()
                }
                
                ForEach(dayGoals.tracked) { goal in
                    let entry = dataStore.getEntry(for: goal.id, on: selectedDate)
                    let oneOff = dataStore.isOneOff(goal.id, on: selectedDate)
                    GoalRow(goal: goal, entry: entry, isOneOff: oneOff, onEdit: oneOff ? { editingOneOff = goal } : nil) {
                        dataStore.cycleStatus(for: goal.id, on: selectedDate)
                    }
                    .contextMenu {
                        if oneOff {
                            Button("Edit…") {
                                editingOneOff = goal
                            }
                            Button("Delete", role: .destructive) {
                                dataStore.deleteOneOffTask(goal.id, on: selectedDate)
                            }
                        } else {
                            Button("Edit Task…") {
                                settingsRouter.editGoal(goal.id)
                                NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
                            }
                            Button("Hide from this day") {
                                dataStore.hideGoal(goal.id, on: selectedDate)
                            }
                        }
                    }
                }
                
                Menu {
                    Button("New one-off task…") {
                        showingOneOff = true
                    }
                    if !addableGoals.isEmpty {
                        Divider()
                        ForEach(addableGoals) { goal in
                            Button {
                                dataStore.addGoalOverride(goal.id, on: selectedDate)
                            } label: {
                                Label(goal.title, systemImage: goal.icon)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.body)
                        Text("Add for this day")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                
                SkippedGoalsSection(goals: dayGoals.skipped)
            }
            .padding(.top, 4)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.top)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private func labeledStat(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count)")
                .font(.caption.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OneOffTaskSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    var existing: Goal? = nil
    
    @State private var title = ""
    @State private var icon = "star.fill"
    
    private let icons = [
        "star.fill", "bolt.fill", "flag.fill", "checkmark.circle.fill",
        "cart.fill", "phone.fill", "envelope.fill", "hammer.fill",
        "book.fill", "heart.fill", "leaf.fill", "lightbulb.fill"
    ]
    
    private var isEditing: Bool { existing != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(isEditing ? "Edit one-off" : "One-off task")
                    .font(.headline)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Only this day — not added to the library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("What do you need to do?", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(icons, id: \.self) { name in
                        Button { icon = name } label: {
                            let tint = GoalIconPalette.color(for: name)
                            Image(systemName: name)
                                .font(.system(size: 14))
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(icon == name ? tint.opacity(0.25) : Color.gray.opacity(0.1))
                                )
                                .foregroundStyle(icon == name ? tint : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if isEditing {
                    Button("Delete", role: .destructive) {
                        if let existing {
                            dataStore.deleteOneOffTask(existing.id, on: date)
                        }
                        dismiss()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            
            Spacer()
        }
        .onAppear {
            if let existing {
                title = existing.title
                icon = existing.icon
            }
        }
    }
    
    private func save() {
        if let existing {
            dataStore.updateOneOffTask(existing.id, title: title, icon: icon, on: date)
        } else {
            dataStore.addOneOffTask(title: title, icon: icon, on: date)
        }
        dismiss()
    }
}

#Preview("Day View") {
    DayView(selectedDate: .constant(Date()))
        .environment(DataStore())
        .environment(PrayerService())
        .environment(AppUsageService())
        .environment(SettingsRouter())
        .frame(width: 400, height: 600)
}
