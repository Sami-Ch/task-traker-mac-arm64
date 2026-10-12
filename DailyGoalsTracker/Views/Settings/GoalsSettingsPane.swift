import SwiftUI
import UniformTypeIdentifiers

struct GoalsSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(SettingsRouter.self) private var settingsRouter

    @State private var showingAddGoal = false
    @State private var editingGoal: Goal?
    @State private var draggedGoalId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(
                    "\(dataStore.goals.filter(\.isActive).count) active · \(dataStore.goals.count) total"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showingAddGoal = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if dataStore.goals.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(dataStore.goals) { goal in
                            GoalSettingsRow(
                                goal: goal,
                                draggedGoalId: $draggedGoalId,
                                onEdit: { editingGoal = goal },
                                onDelete: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        dataStore.deleteGoal(goal)
                                    }
                                },
                                onMove: { source, destination in
                                    dataStore.moveGoal(from: source, to: destination)
                                }
                            )
                        }
                    } footer: {
                        Text("Drag the handle to reorder. Right-click a task to edit or delete.")
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddGoal) {
            GoalEditorSheet(goal: nil)
                .frame(width: 400, height: 640)
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditorSheet(goal: goal)
                .frame(width: 400, height: 640)
        }
        .onAppear { consumePendingGoalEdit() }
        .onChange(of: settingsRouter.goalIdToEdit) { _, _ in
            consumePendingGoalEdit()
        }
    }

    private func consumePendingGoalEdit() {
        guard let goalId = settingsRouter.goalIdToEdit,
            let goal = dataStore.goals.first(where: { $0.id == goalId })
        else { return }
        settingsRouter.clearGoalEdit()
        // Present after the settings window is key. The first open creates
        // that window in the same turn as this view appearing.
        DispatchQueue.main.async {
            editingGoal = goal
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No Tasks Yet")
                .font(.headline)

            Text("Add your first task to start tracking the day.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Add Task") {
                showingAddGoal = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Goal Settings Row

struct GoalSettingsRow: View {
    let goal: Goal
    @Binding var draggedGoalId: UUID?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMove: (IndexSet, Int) -> Void

    @Environment(DataStore.self) private var dataStore
    @State private var isHovered = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 20)
                .contentShape(Rectangle())
                .onDrag {
                    draggedGoalId = goal.id
                    return NSItemProvider(object: goal.id.uuidString as NSString)
                }

            GoalIconView(icon: goal.icon, size: 14, isActive: goal.isActive)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(goal.isActive ? .primary : .secondary)
                    .lineLimit(1)
                    .onTapGesture(count: 2, perform: onEdit)

                Text(detailSubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Edit task")

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete task")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            Toggle(
                "",
                isOn: Binding(
                    get: { goal.isActive },
                    set: { newValue in
                        var updated = goal
                        updated.isActive = newValue
                        dataStore.updateGoal(updated)
                    }
                )
            )
            .toggleStyle(.switch)
            .scaleEffect(0.8)
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onDrop(
            of: [UTType.plainText],
            delegate: GoalReorderDropDelegate(
                targetGoal: goal,
                goals: dataStore.goals,
                draggedGoalId: $draggedGoalId,
                onMove: onMove
            )
        )
        .contextMenu {
            Button("Edit Task…", action: onEdit)
            Button("Delete…", role: .destructive) { showDeleteConfirm = true }
        }
        .alert("Delete Task?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Remove \"\(goal.title)\" from the library? Past frozen days keep their history.")
        }
    }

    private var detailSubtitle: String {
        if goal.weekdays == .all { return goal.trackingSubtitle }
        return "\(goal.trackingSubtitle) · \(weekdaysSummary)"
    }

    private var weekdaysSummary: String {
        let days = WeekdaySet.mondayFirst.filter { goal.weekdays.contains($0) }
        if days.count <= 3 {
            return days.map { dayAbbreviation(for: $0) }.joined(separator: ", ")
        } else {
            return "\(days.count) days/week"
        }
    }

    private func dayAbbreviation(for day: WeekdaySet) -> String {
        switch day {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        default: return ""
        }
    }
}

// MARK: - Reorder Drop Delegate

private struct GoalReorderDropDelegate: DropDelegate {
    let targetGoal: Goal
    let goals: [Goal]
    @Binding var draggedGoalId: UUID?
    let onMove: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedGoalId,
            draggedGoalId != targetGoal.id,
            let from = goals.firstIndex(where: { $0.id == draggedGoalId }),
            let to = goals.firstIndex(where: { $0.id == targetGoal.id })
        else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            onMove(IndexSet(integer: from), to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedGoalId = nil
        return true
    }
}

// MARK: - Goal Editor Sheet

struct GoalEditorSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss

    let goal: Goal?

    @State private var title: String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var weekdays: WeekdaySet = .all
    @State private var kind: GoalKind = .checklist
    @State private var targetCount: Int = 1
    @State private var unit: String = ""
    @State private var step: Int = 1
    @State private var hourBound: HourBound = .atLeast
    @State private var targetMinutes: Int = 60
    @State private var floorMinutes: Int = 30
    @State private var previewStatus: GoalStatus = .partial
    @State private var previewPercent: Int = 40
    @State private var previewAmount: Int = 0
    @State private var previewGoalId = UUID()

    private let iconOptions = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill",
        "figure.run", "book.fill", "brain.head.profile", "leaf.fill",
        "lightbulb.fill", "hammer.fill", "drop.fill", "moon.fill",
        "sun.max.fill", "pencil", "music.note", "gamecontroller.fill",
        "cart.fill", "phone.fill", "envelope.fill", "house.fill",
        "car.fill", "airplane", "graduationcap.fill", "dollarsign.circle.fill",
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(goal == nil ? "New Task" : "Edit Task")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button("Save") { saveGoal() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Enter task name", text: $title)
                            .textFieldStyle(.roundedBorder)
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekdays")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        WeekdayChipsView(
                            weekdays: $weekdays,
                            presentation: dataStore.calendarPresentation
                        )

                        Text(
                            "Select which days this task appears. Fine-tune the full list in Schedule settings."
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                            spacing: 8
                        ) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    let tint = GoalIconPalette.color(for: icon)
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    selectedIcon == icon
                                                        ? tint.opacity(0.25)
                                                        : Color.gray.opacity(0.1))
                                        )
                                        .foregroundStyle(selectedIcon == icon ? tint : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

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

                        Text(
                            kind == .checklist
                                ? "Tap the circle to cycle its state."
                                : "Tap the pill to open the editor, the same as in the day list."
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
            }
        }
        .onAppear {
            if let goal {
                title = goal.title
                selectedIcon = goal.icon
                weekdays = goal.weekdays
                kind = goal.kind
                targetCount = goal.safeTarget
                unit = goal.unit
                step =
                    goal.kind == .hours
                    ? goal.safeHourStep
                    : (goal.kind == .percent ? goal.safePercentStep : goal.safeCountStep)
                hourBound = goal.hourBound
                targetMinutes = goal.safeTargetMinutes
                floorMinutes = goal.hourBound == .between ? goal.safeFloorMinutes : 30
                previewAmount = 0
                previewPercent = 40
                previewStatus = .partial
            }
        }
    }

    private var previewGoal: Goal {
        Goal(
            id: previewGoalId,
            title: title.isEmpty ? "Task Name" : title,
            icon: selectedIcon,
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
            return GoalEntry(goalId: previewGoalId, date: .now, status: previewStatus)
        case .percent:
            return GoalEntry(
                goalId: previewGoalId,
                date: .now,
                status: GoalStatus.from(progress: Double(previewPercent) / 100),
                percent: previewPercent
            )
        case .count:
            let progress = min(1, Double(previewAmount) / Double(max(1, targetCount)))
            return GoalEntry(
                goalId: previewGoalId,
                date: .now,
                status: GoalStatus.from(progress: progress),
                amount: previewAmount
            )
        case .hours:
            let progress = previewGoal.loggedProgress(previewAmount)
            return GoalEntry(
                goalId: previewGoalId,
                date: .now,
                status: GoalStatus.from(progress: progress),
                amount: previewAmount
            )
        }
    }

    private func saveGoal() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        if let existingGoal = goal {
            var updated = existingGoal
            updated.title = trimmedTitle
            updated.icon = selectedIcon
            updated.weekdays = weekdays
            updated.kind = kind
            updated.targetCount = Goal.clampedTarget(targetCount)
            updated.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.step = Goal.storedStep(kind: kind, step: step, targetCount: targetCount)
            updated.hourBound = hourBound
            updated.targetMinutes = Goal.clampedMinutes(targetMinutes)
            updated.floorMinutes = hourBound == .between ? floorMinutes : 0
            dataStore.updateGoal(updated)
        } else {
            dataStore.addGoal(
                Goal(
                    title: trimmedTitle,
                    icon: selectedIcon,
                    weekdays: weekdays,
                    kind: kind,
                    targetCount: targetCount,
                    unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
                    step: Goal.storedStep(kind: kind, step: step, targetCount: targetCount),
                    hourBound: hourBound,
                    targetMinutes: targetMinutes,
                    floorMinutes: hourBound == .between ? floorMinutes : 0
                )
            )
        }

        dismiss()
    }
}

// MARK: - Tracking fields

struct TaskTrackingFields: View {
    @Binding var kind: GoalKind
    @Binding var targetCount: Int
    @Binding var unit: String
    @Binding var step: Int
    @Binding var hourBound: HourBound
    @Binding var targetMinutes: Int
    @Binding var floorMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tracking")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Picker("Tracking", selection: $kind) {
                ForEach(GoalKind.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(kind.caption)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if kind == .count {
                countFields
            }

            if kind == .percent {
                percentFields
            }

            if kind == .hours {
                hoursFields
            }
        }
        .onChange(of: kind) { _, newKind in
            switch newKind {
            case .hours:
                step = Goal.clampedHourStep(step)
            case .percent:
                if step <= 1 { step = 10 }
            case .count:
                step = Goal.clampedStep(step, target: targetCount)
            case .checklist:
                break
            }
        }
    }

    private var countFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            CountDigitField(
                title: "Max",
                hint: "The day list stops here",
                value: $targetCount,
                range: 1...9999
            )

            CountDigitField(
                title: "Each tap",
                hint: "Added when you tap the pill",
                value: $step,
                range: 1...max(1, targetCount)
            )

            Text(
                "Tap the pill to add \(max(1, step)). Tap the task name to open the slider. It stops at \(targetCount)."
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            TextField("Unit, such as pages or glasses", text: $unit)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var percentFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            CountDigitField(
                title: "Each tap",
                hint: "Percent added by the pill. Default is 10.",
                value: $step,
                range: 5...100
            )
        }
    }

    private var hoursFields: some View {
        HourLimitsEditor(
            hourBound: $hourBound,
            targetMinutes: $targetMinutes,
            floorMinutes: $floorMinutes,
            step: $step
        )
    }

    private func valueRow<StepperControl: View>(
        title: String,
        value: String,
        @ViewBuilder stepper: () -> StepperControl
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
            stepper()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

/// At least, at most, or both. Turning one on chooses that rule. Turning both on requires the time to land between them.
private struct HourLimitsEditor: View {
    @Binding var hourBound: HourBound
    @Binding var targetMinutes: Int
    @Binding var floorMinutes: Int
    @Binding var step: Int

    @State private var useAtLeast = true
    @State private var useAtMost = false
    @State private var leastMinutes = 60
    @State private var mostMinutes = 120
    @State private var didLoad = false

    private var minuteStep: Int { Goal.clampedHourStep(step) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            limitRow(
                title: "At least",
                hint: "Done once you reach this, even if you go longer.",
                isOn: atLeastBinding,
                minutes: $leastMinutes
            )
            limitRow(
                title: "At most",
                hint: "Done from zero up to this. Going over marks it missed.",
                isOn: atMostBinding,
                minutes: $mostMinutes
            )

            Text(hourBound.caption)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Each tap")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach([1, 5, 10, 15, 30], id: \.self) { minutes in
                        let selected = minuteStep == minutes
                        Button {
                            step = minutes
                        } label: {
                            Text("\(minutes)m")
                                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: leastMinutes) { _, _ in publish() }
        .onChange(of: mostMinutes) { _, _ in publish() }
    }

    private var atLeastBinding: Binding<Bool> {
        Binding(
            get: { useAtLeast },
            set: { on in
                useAtLeast = on
                if !on && !useAtMost { useAtMost = true }
                publish()
            }
        )
    }

    private var atMostBinding: Binding<Bool> {
        Binding(
            get: { useAtMost },
            set: { on in
                useAtMost = on
                if !on && !useAtLeast { useAtLeast = true }
                publish()
            }
        )
    }

    private func limitRow(title: String, hint: String, isOn: Binding<Bool>, minutes: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            if isOn.wrappedValue {
                HStack {
                    Text(Goal.formatMinutes(minutes.wrappedValue))
                        .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    Spacer()
                    Stepper(title, value: minutes, in: 15...24 * 60, step: 15)
                        .labelsHidden()
                }
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        switch hourBound {
        case .atLeast:
            useAtLeast = true
            useAtMost = false
            leastMinutes = targetMinutes
        case .atMost:
            useAtLeast = false
            useAtMost = true
            mostMinutes = targetMinutes
        case .between:
            useAtLeast = true
            useAtMost = true
            leastMinutes = floorMinutes
            mostMinutes = targetMinutes
        }
    }

    private func publish() {
        if useAtLeast && useAtMost {
            var floor = Goal.clampedMinutes(leastMinutes)
            var ceiling = Goal.clampedMinutes(mostMinutes)
            if ceiling < floor {
                ceiling = floor
                mostMinutes = ceiling
            }
            hourBound = .between
            floorMinutes = floor
            targetMinutes = ceiling
        } else if useAtMost {
            hourBound = .atMost
            targetMinutes = Goal.clampedMinutes(mostMinutes)
            floorMinutes = 0
        } else {
            hourBound = .atLeast
            targetMinutes = Goal.clampedMinutes(leastMinutes)
            floorMinutes = 0
        }
    }
}

/// A typed whole number. Digits only, and it stays inside the allowed range.
private struct CountDigitField: View {
    let title: String
    let hint: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var onCommit: () -> Void = {}

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                .focused($focused)
                .onAppear { text = "\(value)" }
                .onChange(of: value) { _, newValue in
                    guard !focused else { return }
                    text = "\(newValue)"
                }
                .onChange(of: text) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(4))
                    if digits != newValue {
                        text = digits
                        return
                    }
                    guard let number = Int(digits), number <= range.upperBound else {
                        if let number = Int(digits), number > range.upperBound {
                            value = range.upperBound
                            text = "\(range.upperBound)"
                        }
                        return
                    }
                    if number >= range.lowerBound {
                        value = number
                    }
                }
                .onChange(of: focused) { _, isFocused in
                    guard !isFocused else { return }
                    let number = Int(text.filter(\.isNumber)) ?? range.lowerBound
                    let clamped = min(range.upperBound, max(range.lowerBound, number))
                    value = clamped
                    text = "\(clamped)"
                    onCommit()
                }

            Text(hint)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(focused ? 0.08 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    focused ? Color.accentColor.opacity(0.75) : Color.primary.opacity(0.06),
                    lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

#Preview("Goals Pane") {
    GoalsSettingsPane()
        .environment(DataStore())
        .environment(SettingsRouter())
        .frame(width: 500, height: 400)
}

#Preview("Goal Editor") {
    GoalEditorSheet(goal: nil)
        .environment(DataStore())
        .frame(width: 400, height: 520)
}
