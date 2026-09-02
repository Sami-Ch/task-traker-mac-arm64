import SwiftUI

/// Settings hub with Goals and Modes panels.
struct SettingsView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.closeSettings) private var closeSettings
    
    @State private var panel: SettingsPanel = .goals
    @State private var showingAddGoal = false
    @State private var editingGoal: Goal?
    @State private var showingAddMode = false
    @State private var editingMode: DayMode?
    
    private enum SettingsPanel: String, CaseIterable {
        case goals = "Goals"
        case modes = "Modes"
        
        var icon: String {
            switch self {
            case .goals: return "checklist"
            case .modes: return "circle.grid.2x2.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            panelPicker
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            Divider()
            
            Group {
                switch panel {
                case .goals:
                    goalsList
                case .modes:
                    modesList
                }
            }
            
            Divider()
            footer
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                closeSettings()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(panel == .goals ? "Track Goals" : "Day Modes")
                .font(.system(size: 15, weight: .semibold))
            
            Spacer()
            
            Button {
                if panel == .goals {
                    showingAddGoal = true
                } else {
                    showingAddMode = true
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help(panel == .goals ? "Add goal" : "Add mode")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Panel Picker
    private var panelPicker: some View {
        HStack(spacing: 2) {
            ForEach(SettingsPanel.allCases, id: \.rawValue) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        panel = item
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 10))
                        Text(item.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(panel == item ? .white : .secondary)
                    .background {
                        if panel == item {
                            Capsule().fill(Color.blue)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.gray.opacity(0.15)))
    }
    
    // MARK: - Goals List
    private var goalsList: some View {
        List {
            ForEach(dataStore.goals) { goal in
                GoalSettingsRow(
                    goal: goal,
                    onEdit: { editingGoal = goal },
                    onDelete: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dataStore.deleteGoal(goal)
                        }
                    }
                )
            }
            .onMove { source, destination in
                dataStore.moveGoal(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showingAddGoal) {
            GoalEditorSheet(goal: nil)
                .frame(width: 340, height: 420)
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditorSheet(goal: goal)
                .frame(width: 340, height: 420)
        }
    }
    
    // MARK: - Modes List
    private var modesList: some View {
        List {
            ForEach(dataStore.sortedDayModes) { mode in
                ModeSettingsRow(
                    mode: mode,
                    onEdit: { editingMode = mode },
                    onDelete: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dataStore.deleteDayMode(mode)
                        }
                    }
                )
            }
            .onMove { source, destination in
                dataStore.moveDayMode(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showingAddMode) {
            ModeEditorSheet(mode: nil)
                .frame(width: 340, height: 480)
        }
        .sheet(item: $editingMode) { mode in
            ModeEditorSheet(mode: mode)
                .frame(width: 340, height: 480)
        }
    }
    
    // MARK: - Footer
    private var footer: some View {
        HStack {
            if panel == .goals {
                Text("\(dataStore.goals.filter(\.isActive).count) active goals")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Toggle to enable tracking")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                Text("\(dataStore.dayModes.count) modes")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Assign goals per mode")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Goal Settings Row
private struct GoalSettingsRow: View {
    let goal: Goal
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @Environment(DataStore.self) private var dataStore
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            
            GoalIconView(icon: goal.icon, size: 12, isActive: goal.isActive)
            
            Text(goal.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(goal.isActive ? .primary : .secondary)
                .lineLimit(1)
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Edit goal")
                    
                    Button { showDeleteConfirm = true } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete goal")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            
            Toggle("", isOn: Binding(
                get: { goal.isActive },
                set: { newValue in
                    var updated = goal
                    updated.isActive = newValue
                    dataStore.updateGoal(updated)
                }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.7)
            .labelsHidden()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .alert("Delete Goal?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Are you sure you want to delete \"\(goal.title)\"? This will also remove all tracking data for this goal.")
        }
    }
}

// MARK: - Mode Settings Row
private struct ModeSettingsRow: View {
    let mode: DayMode
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    
    private var canDelete: Bool {
        mode.id != DayMode.normalId && !mode.tracksAllGoals
    }
    
    private var goalSummary: String {
        if mode.tracksAllGoals {
            return "All goals"
        }
        let count = mode.acceptedGoalIds.count
        return count == 0 ? "No goals" : "\(count) goal\(count == 1 ? "" : "s")"
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            
            ZStack {
                Circle()
                    .fill(mode.color.opacity(0.18))
                    .frame(width: 22, height: 22)
                Image(systemName: mode.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(mode.color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(mode.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(goalSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
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
                    .help("Edit mode")
                    
                    if canDelete {
                        Button { showDeleteConfirm = true } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Delete mode")
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(perform: onEdit)
        .alert("Delete Mode?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Delete \"\(mode.title)\"? Days using this mode will switch back to Normal.")
        }
    }
}

// MARK: - Add/Edit Goal Sheet
struct GoalEditorSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let goal: Goal?
    
    @State private var title: String = ""
    @State private var selectedIcon: String = "star.fill"
    
    private let iconOptions = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill",
        "figure.run", "book.fill", "brain.head.profile", "leaf.fill",
        "lightbulb.fill", "hammer.fill", "drop.fill", "moon.fill",
        "sun.max.fill", "pencil", "music.note", "gamecontroller.fill",
        "cart.fill", "phone.fill", "envelope.fill", "house.fill",
        "car.fill", "airplane", "graduationcap.fill", "dollarsign.circle.fill"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(goal == nil ? "New Goal" : "Edit Goal")
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
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal Name")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter goal name", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button { selectedIcon = icon } label: {
                                let tint = GoalIconPalette.color(for: icon)
                                Image(systemName: icon)
                                    .font(.system(size: 18))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? tint.opacity(0.25) : Color.gray.opacity(0.1))
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
                    
                    HStack(spacing: 12) {
                        GoalIconView(icon: selectedIcon, size: 14)
                        Text(title.isEmpty ? "Goal Name" : title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(title.isEmpty ? .secondary : .primary)
                        Spacer()
                        StatusIndicator(status: .done)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
            }
            .padding(16)
            
            Spacer()
        }
        .onAppear {
            if let goal {
                title = goal.title
                selectedIcon = goal.icon
            }
        }
    }
    
    private func saveGoal() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        if let existingGoal = goal {
            var updated = existingGoal
            updated.title = trimmedTitle
            updated.icon = selectedIcon
            dataStore.updateGoal(updated)
        } else {
            dataStore.addGoal(Goal(title: trimmedTitle, icon: selectedIcon))
        }
        
        dismiss()
    }
}

// MARK: - Add/Edit Mode Sheet
struct ModeEditorSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let mode: DayMode?
    
    @State private var title: String = ""
    @State private var shortTitle: String = ""
    @State private var selectedIcon: String = "moon.stars.fill"
    @State private var selectedColor: String = "purple"
    @State private var acceptedGoalIds: Set<UUID> = []
    
    private var isNormalMode: Bool {
        mode?.id == DayMode.normalId || mode?.tracksAllGoals == true
    }
    
    private let iconOptions = [
        "calendar", "moon.stars.fill", "airplane", "bed.double.fill", "leaf.fill",
        "heart.fill", "flame.fill", "bolt.fill", "cloud.rain.fill", "snowflake",
        "figure.walk", "cup.and.saucer.fill", "book.fill", "dumbbell.fill",
        "briefcase.fill", "house.fill", "car.fill", "ferry.fill", "beach.umbrella.fill",
        "cross.case.fill", "pills.fill", "figure.mind.and.body", "sparkles", "star.fill"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(mode == nil ? "New Mode" : "Edit Mode")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Button("Save") { saveMode() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mode Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("e.g. Fasting", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Short Label")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Shown on chips", text: $shortTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(ModeColorName.allCases) { color in
                                Button {
                                    selectedColor = color.rawValue
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 22, height: 22)
                                        .overlay {
                                            if selectedColor == color.rawValue {
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 2)
                                                    .padding(2)
                                                Circle()
                                                    .strokeBorder(color.color, lineWidth: 2)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .help(color.label)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button { selectedIcon = icon } label: {
                                    let tint = ModeColorName(rawValue: selectedColor)?.color ?? .blue
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIcon == icon ? tint.opacity(0.25) : Color.gray.opacity(0.1))
                                        )
                                        .foregroundStyle(selectedIcon == icon ? tint : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    goalsSection
                }
                .padding(16)
            }
        }
        .onAppear {
            if let mode {
                title = mode.title
                shortTitle = mode.shortTitle
                selectedIcon = mode.icon
                selectedColor = mode.colorName
                acceptedGoalIds = Set(mode.acceptedGoalIds)
            }
        }
    }
    
    @ViewBuilder
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goals for this mode")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            if isNormalMode {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Normal mode tracks all active goals")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.08)))
            } else if dataStore.goals.isEmpty {
                Text("Add goals in the Goals panel first.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 2) {
                    ForEach(dataStore.goals) { goal in
                        let isAccepted = acceptedGoalIds.contains(goal.id)
                        Button {
                            if isAccepted {
                                acceptedGoalIds.remove(goal.id)
                            } else {
                                acceptedGoalIds.insert(goal.id)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                GoalIconView(icon: goal.icon, size: 11, isActive: goal.isActive)
                                Text(goal.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(goal.isActive ? .primary : .secondary)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: isAccepted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isAccepted ? .blue : .gray.opacity(0.35))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isAccepted ? Color.blue.opacity(0.08) : Color.gray.opacity(0.06))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(goal.isActive ? 1 : 0.55)
                    }
                }
                
                Text("\(acceptedGoalIds.count) selected · unchecked goals are skipped on this mode")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private func saveMode() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        let trimmedShort = shortTitle.trimmingCharacters(in: .whitespaces)
        
        if let existing = mode {
            var updated = existing
            updated.title = trimmedTitle
            updated.shortTitle = trimmedShort.isEmpty ? String(trimmedTitle.prefix(8)) : trimmedShort
            updated.icon = selectedIcon
            updated.colorName = selectedColor
            if !existing.tracksAllGoals {
                updated.acceptedGoalIds = Array(acceptedGoalIds)
            }
            dataStore.updateDayMode(updated)
        } else {
            let newMode = DayMode(
                title: trimmedTitle,
                shortTitle: trimmedShort.isEmpty ? nil : trimmedShort,
                icon: selectedIcon,
                colorName: selectedColor,
                tracksAllGoals: false,
                acceptedGoalIds: Array(acceptedGoalIds)
            )
            dataStore.addDayMode(newMode)
        }
        
        dismiss()
    }
}

// MARK: - Preview
#Preview("Settings View") {
    SettingsView()
        .environment(DataStore())
        .frame(width: 340, height: 480)
}

#Preview("Goal Editor") {
    GoalEditorSheet(goal: nil)
        .environment(DataStore())
        .frame(width: 340, height: 400)
}

#Preview("Mode Editor") {
    ModeEditorSheet(mode: nil)
        .environment(DataStore())
        .frame(width: 340, height: 480)
}
