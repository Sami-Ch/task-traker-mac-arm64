import SwiftUI

/// Planning view for weekly, monthly, yearly and life goals
struct PlanningView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var expandedHorizons: Set<PlanningHorizon> = [.week, .month]
    @State private var newGoalText: [PlanningHorizon: String] = [:]
    @State private var editingGoal: PlanningGoal?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(PlanningHorizon.allCases) { horizon in
                    PlanningSection(
                        horizon: horizon,
                        isExpanded: expandedHorizons.contains(horizon),
                        newGoalText: Binding(
                            get: { newGoalText[horizon] ?? "" },
                            set: { newGoalText[horizon] = $0 }
                        ),
                        onToggleExpand: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedHorizons.contains(horizon) {
                                    expandedHorizons.remove(horizon)
                                } else {
                                    expandedHorizons.insert(horizon)
                                }
                            }
                        },
                        onAddGoal: {
                            addGoal(for: horizon)
                        },
                        onEditGoal: { goal in
                            editingGoal = goal
                        }
                    )
                }
            }
            .padding(.vertical, 12)
        }
        .sheet(item: $editingGoal) { goal in
            PlanningGoalEditor(goal: goal)
                .frame(width: 320, height: 200)
        }
    }
    
    private func addGoal(for horizon: PlanningHorizon) {
        let text = (newGoalText[horizon] ?? "").trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        let goal = PlanningGoal(title: text, horizon: horizon)
        dataStore.addPlanningGoal(goal)
        newGoalText[horizon] = ""
        
        // Auto-expand if collapsed
        if !expandedHorizons.contains(horizon) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expandedHorizons.insert(horizon)
            }
        }
    }
}

// MARK: - Planning Section
struct PlanningSection: View {
    @Environment(DataStore.self) private var dataStore
    
    let horizon: PlanningHorizon
    let isExpanded: Bool
    @Binding var newGoalText: String
    let onToggleExpand: () -> Void
    let onAddGoal: () -> Void
    let onEditGoal: (PlanningGoal) -> Void
    
    private var goals: [PlanningGoal] {
        dataStore.getPlanningGoals(for: horizon)
    }
    
    private var stats: (completed: Int, total: Int) {
        dataStore.getPlanningStats(for: horizon)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            sectionHeader
            
            // Content
            if isExpanded {
                VStack(spacing: 8) {
                    // Goals list
                    if goals.isEmpty {
                        emptyState
                    } else {
                        ForEach(goals) { goal in
                            PlanningGoalRow(
                                goal: goal,
                                onToggle: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                        dataStore.togglePlanningGoalCompletion(goal.id)
                                    }
                                },
                                onEdit: {
                                    onEditGoal(goal)
                                },
                                onDelete: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        dataStore.deletePlanningGoal(goal)
                                    }
                                }
                            )
                        }
                    }
                    
                    // Add new goal input
                    addGoalInput
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .padding(.horizontal, 12)
    }
    
    private var sectionHeader: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: horizon.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(horizon.color)
                    .frame(width: 20)
                
                // Title
                Text(horizon.title)
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                // Stats badge
                if stats.total > 0 {
                    Text("\(stats.completed)/\(stats.total)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.15))
                        )
                }
                
                // Expand/collapse indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var emptyState: some View {
        Text(horizon.placeholder)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
    
    private var addGoalInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 14))
                .foregroundStyle(horizon.color.opacity(0.6))
            
            TextField("Add a goal...", text: $newGoalText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(onAddGoal)
            
            if !newGoalText.isEmpty {
                Button(action: onAddGoal) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(horizon.color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Planning Goal Row
struct PlanningGoalRow: View {
    let goal: PlanningGoal
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(goal.isCompleted ? .green : .gray.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(StatusButtonStyle())
            
            // Title
            Text(goal.title)
                .font(.system(size: 13))
                .strikethrough(goal.isCompleted, color: .secondary)
                .foregroundStyle(goal.isCompleted ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action buttons (on hover)
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Planning Goal Editor
struct PlanningGoalEditor: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let goal: PlanningGoal
    @State private var title: String = ""
    @State private var notes: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Edit Goal")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                Button("Save") { saveGoal() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            VStack(spacing: 12) {
                TextField("Goal title", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
            }
            .padding(16)
            
            Spacer()
        }
        .onAppear {
            title = goal.title
            notes = goal.notes ?? ""
        }
    }
    
    private func saveGoal() {
        var updated = goal
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.notes = notes.isEmpty ? nil : notes
        dataStore.updatePlanningGoal(updated)
        dismiss()
    }
}

// MARK: - Preview
#Preview("Planning View") {
    PlanningView()
        .environment(DataStore())
        .frame(width: 340, height: 500)
}
