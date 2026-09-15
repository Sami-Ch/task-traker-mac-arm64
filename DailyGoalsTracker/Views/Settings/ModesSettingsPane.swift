import SwiftUI

struct ModesSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    
    @State private var showingAddMode = false
    @State private var editingMode: DayMode?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(dataStore.dayModes.count) modes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    showingAddMode = true
                } label: {
                    Label("Add Mode", systemImage: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            Divider()
            
            // Modes list
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
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .navigationTitle("Day Modes")
        .sheet(isPresented: $showingAddMode) {
            ModeEditorSheet(mode: nil)
                .frame(width: 400, height: 500)
        }
        .sheet(item: $editingMode) { mode in
            ModeEditorSheet(mode: mode)
                .frame(width: 400, height: 500)
        }
    }
}

// MARK: - Mode Settings Row

struct ModeSettingsRow: View {
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
                    .frame(width: 26, height: 26)
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(mode.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, 4)
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

// MARK: - Mode Editor Sheet

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
                                        .frame(width: 24, height: 24)
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

#Preview("Modes Pane") {
    ModesSettingsPane()
        .environment(DataStore())
        .frame(width: 500, height: 400)
}

#Preview("Mode Editor") {
    ModeEditorSheet(mode: nil)
        .environment(DataStore())
        .frame(width: 400, height: 500)
}
