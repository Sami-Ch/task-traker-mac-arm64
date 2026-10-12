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
                .frame(width: 380, height: 560)
        }
        .sheet(item: $editingOneOff) { goal in
            OneOffTaskSheet(date: selectedDate, existing: goal)
                .frame(width: 380, height: 560)
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
                    GoalRow(goal: goal, entry: entry, isOneOff: oneOff, onEdit: oneOff ? { editingOneOff = goal } : nil, onSetPercent: { percent in
                        dataStore.setPercent(percent, for: goal.id, on: selectedDate)
                    }, onSetAmount: { amount in
                        dataStore.setAmount(amount, for: goal.id, on: selectedDate)
                    }, onAdjustAmount: { delta in
                        dataStore.adjustAmount(for: goal.id, on: selectedDate, by: delta)
                    }) {
                        dataStore.cycleStatus(for: goal.id, on: selectedDate)
                    }
                    .id("\(goal.id.uuidString)-\(GoalEntry.dateString(from: selectedDate))")
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
                
                SkippedGoalsSection(goals: dayGoals.skipped, date: selectedDate)
            }
            .padding(.top, 4)
            .padding(.bottom, 6)
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
    @State private var kind: GoalKind = .checklist
    @State private var targetCount = 1
    @State private var unit = ""
    @State private var step = 1
    @State private var hourBound: HourBound = .atLeast
    @State private var targetMinutes = 60
    @State private var floorMinutes = 30
    @State private var previewStatus: GoalStatus = .notDone
    @State private var previewPercent = 0
    @State private var previewAmount = 0
    @State private var previewGoalId = UUID()
    
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
                    
                    TaskTrackingFields(
                        kind: $kind,
                        targetCount: $targetCount,
                        unit: $unit,
                        step: $step,
                        hourBound: $hourBound,
                        targetMinutes: $targetMinutes,
                        floorMinutes: $floorMinutes
                    )
                    
                    GoalRow(
                        goal: previewGoal,
                        entry: previewEntry,
                        onSetPercent: { value in
                            previewPercent = min(100, max(0, value))
                        },
                        onSetAmount: { value in
                            previewAmount = min(max(1, targetCount), max(0, value))
                        },
                        onAdjustAmount: { delta in
                            let next = previewAmount + delta
                            if kind == .count, delta > 0 {
                                previewAmount = min(max(1, targetCount), max(0, next))
                            } else {
                                previewAmount = max(0, next)
                            }
                        },
                        onStatusChange: { previewStatus = previewStatus.next }
                    )
                    .id(kind)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.08))
                    )
                    
                    if isEditing {
                        Button("Delete", role: .destructive) {
                            if let existing {
                                dataStore.deleteOneOffTask(existing.id, on: date)
                            }
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
        }
        .onAppear {
            if let existing {
                title = existing.title
                icon = existing.icon
                kind = existing.kind
                targetCount = existing.safeTarget
                unit = existing.unit
                step = existing.kind == .hours ? existing.safeHourStep : (existing.kind == .percent ? existing.safePercentStep : existing.safeCountStep)
                hourBound = existing.hourBound
                targetMinutes = existing.safeTargetMinutes
                floorMinutes = existing.hourBound == .between ? existing.safeFloorMinutes : 30
                previewGoalId = existing.id
            }
        }
    }
    
    private var previewGoal: Goal {
        Goal(
            id: previewGoalId,
            title: title.isEmpty ? "Task" : title,
            icon: icon,
            kind: kind,
            targetCount: targetCount,
            unit: unit,
            step: step,
            hourBound: hourBound,
            targetMinutes: targetMinutes,
            floorMinutes: floorMinutes
        )
    }
    
    private var previewEntry: GoalEntry {
        switch kind {
        case .checklist:
            return GoalEntry(goalId: previewGoalId, date: date, status: previewStatus)
        case .percent:
            return GoalEntry(
                goalId: previewGoalId,
                date: date,
                status: GoalStatus.from(progress: Double(previewPercent) / 100),
                percent: previewPercent
            )
        case .count:
            let progress = min(1, Double(previewAmount) / Double(max(1, targetCount)))
            return GoalEntry(
                goalId: previewGoalId,
                date: date,
                status: GoalStatus.from(progress: progress),
                amount: previewAmount
            )
        case .hours:
            let progress = previewGoal.loggedProgress(previewAmount)
            return GoalEntry(
                goalId: previewGoalId,
                date: date,
                status: GoalStatus.from(progress: progress),
                amount: previewAmount
            )
        }
    }
    
    private func save() {
        let savedStep = Goal.storedStep(kind: kind, step: step, targetCount: targetCount)
        let savedFloor = hourBound == .between ? floorMinutes : 0
        if let existing {
            dataStore.updateOneOffTask(
                existing.id,
                title: title,
                icon: icon,
                kind: kind,
                targetCount: targetCount,
                unit: unit,
                step: savedStep,
                hourBound: hourBound,
                targetMinutes: targetMinutes,
                floorMinutes: savedFloor,
                on: date
            )
        } else {
            dataStore.addOneOffTask(
                title: title,
                icon: icon,
                kind: kind,
                targetCount: targetCount,
                unit: unit,
                step: savedStep,
                hourBound: hourBound,
                targetMinutes: targetMinutes,
                floorMinutes: savedFloor,
                on: date
            )
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
