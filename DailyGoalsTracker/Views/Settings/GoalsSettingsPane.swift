import SwiftUI

struct GoalsSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    
    @State private var showingAddGoal = false
    @State private var editingGoal: Goal?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(dataStore.goals.filter(\.isActive).count) active goals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    showingAddGoal = true
                } label: {
                    Label("Add Goal", systemImage: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            Divider()
            
            // Goals list
            if dataStore.goals.isEmpty {
                emptyState
            } else {
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
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Goals")
        .sheet(isPresented: $showingAddGoal) {
            GoalEditorSheet(goal: nil)
                .frame(width: 400, height: 520)
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditorSheet(goal: goal)
                .frame(width: 400, height: 520)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No Goals Yet")
                .font(.headline)
            
            Text("Add your first goal to start tracking daily habits.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Goal") {
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
            
            GoalIconView(icon: goal.icon, size: 14, isActive: goal.isActive)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(goal.isActive ? .primary : .secondary)
                    .lineLimit(1)
                
                if goal.weekdays != .all {
                    Text(weekdaysSummary)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
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
        .onTapGesture(perform: onEdit)
        .alert("Delete Goal?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Remove \"\(goal.title)\" from the library? Past frozen days keep their history.")
        }
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

// MARK: - Goal Editor Sheet

struct GoalEditorSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let goal: Goal?
    
    @State private var title: String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var weekdays: WeekdaySet = .all
    
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
            
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("Enter goal name", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekdays")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        WeekdayChipsView(
                            weekdays: $weekdays,
                            presentation: dataStore.calendarPresentation
                        )
                        
                        Text("Select which days this goal appears. Fine-tune the full list in Schedule settings.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
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
            }
        }
        .onAppear {
            if let goal {
                title = goal.title
                selectedIcon = goal.icon
                weekdays = goal.weekdays
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
            updated.weekdays = weekdays
            dataStore.updateGoal(updated)
        } else {
            dataStore.addGoal(Goal(title: trimmedTitle, icon: selectedIcon, weekdays: weekdays))
        }
        
        dismiss()
    }
}

#Preview("Goals Pane") {
    GoalsSettingsPane()
        .environment(DataStore())
        .frame(width: 500, height: 400)
}

#Preview("Goal Editor") {
    GoalEditorSheet(goal: nil)
        .environment(DataStore())
        .frame(width: 400, height: 520)
}
