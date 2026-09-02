import SwiftUI

/// Settings view for managing goals and app preferences
struct SettingsView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.closeSettings) private var closeSettings
    
    @State private var showingAddGoal = false
    @State private var editingGoal: Goal?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Goals list
            goalsList
            
            Divider()
            
            // Footer
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
            
            Text("Manage Goals")
                .font(.system(size: 15, weight: .semibold))
            
            Spacer()
            
            Button {
                showingAddGoal = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
    
    // MARK: - Footer
    private var footer: some View {
        HStack {
            Text("\(dataStore.goals.filter { $0.isActive }.count) active goals")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("Star = essential on special days")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
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
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            
            GoalIconView(icon: goal.icon, size: 12, isActive: goal.isActive)
            
            // Goal title
            HStack(spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(goal.isActive ? .primary : .secondary)
                    .lineLimit(1)
                if goal.isEssential {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                }
            }
            
            Spacer()

            // Action buttons (visible on hover)
            if isHovered {
                HStack(spacing: 8) {
                    // Edit button
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Edit goal")
                    
                    // Delete button
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete goal")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            
            // Essential toggle
            Button {
                var updated = goal
                updated.isEssential.toggle()
                dataStore.updateGoal(updated)
            } label: {
                Image(systemName: goal.isEssential ? "star.fill" : "star")
                    .font(.system(size: 13))
                    .foregroundStyle(goal.isEssential ? .yellow : .gray.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help(goal.isEssential ? "Essential on special days" : "Mark as essential")
            
            
            // Active toggle
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
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(goal.title)\"? This will also remove all tracking data for this goal.")
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
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(goal == nil ? "New Goal" : "Edit Goal")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Button("Save") {
                    saveGoal()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Form
            VStack(spacing: 20) {
                // Title field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal Name")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter goal name", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Icon picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
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
                                            .fill(selectedIcon == icon ? tint.opacity(0.25) : Color.gray.opacity(0.1))
                                    )
                                    .foregroundStyle(selectedIcon == icon ? tint : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Preview
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
            if let goal = goal {
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
            let newGoal = Goal(title: trimmedTitle, icon: selectedIcon)
            dataStore.addGoal(newGoal)
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
