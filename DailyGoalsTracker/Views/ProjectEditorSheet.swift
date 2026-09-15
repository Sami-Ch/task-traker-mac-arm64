import SwiftUI

/// Editor sheet for creating/editing a project
struct ProjectEditorSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let project: Project?
    
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var hasDeadline = false
    @State private var targetDate = Date()
    @State private var linkedGoalIds: Set<UUID> = []
    @State private var hasTargetCount = false
    @State private var targetCount = 50
    @State private var selectedColor = "blue"
    @State private var selectedIcon = "flag.fill"
    
    private var isEditing: Bool { project != nil }
    
    private let iconOptions = [
        "flag.fill", "star.fill", "heart.fill", "bolt.fill", "flame.fill",
        "figure.run", "book.fill", "brain.head.profile", "leaf.fill",
        "lightbulb.fill", "hammer.fill", "graduationcap.fill", "globe",
        "airplane", "car.fill", "house.fill", "building.2.fill",
        "music.note", "paintbrush.fill", "camera.fill", "gamecontroller.fill",
        "dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "trophy.fill", "medal.fill"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Form content
            ScrollView {
                VStack(spacing: 20) {
                    basicInfoSection
                    datesSection
                    linkedGoalsSection
                    targetCountSection
                    appearanceSection
                }
                .padding(16)
            }
        }
        .onAppear(perform: loadProject)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(isEditing ? "Edit Project" : "New Project")
                .font(.system(size: 14, weight: .semibold))
            
            Spacer()
            
            Button("Save") { saveProject() }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Project Name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("e.g., Learn Spanish", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Description (optional)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("What's this project about?", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
    }
    
    // MARK: - Dates Section
    
    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Date")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Target Date", isOn: $hasDeadline)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    
                    if hasDeadline {
                        DatePicker("", selection: $targetDate, in: startDate..., displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    // MARK: - Linked Goals Section
    
    private var linkedGoalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Link Daily Tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Progress auto-counts completions")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            
            if dataStore.goals.isEmpty {
                Text("No daily goals to link. Create some first in Settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(10)
            } else {
                VStack(spacing: 2) {
                    ForEach(dataStore.goals.filter(\.isActive)) { goal in
                        let isLinked = linkedGoalIds.contains(goal.id)
                        Button {
                            if isLinked {
                                linkedGoalIds.remove(goal.id)
                            } else {
                                linkedGoalIds.insert(goal.id)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                GoalIconView(icon: goal.icon, size: 11, isActive: true)
                                Text(goal.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isLinked ? .blue : .gray.opacity(0.35))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isLinked ? Color.blue.opacity(0.08) : Color.gray.opacity(0.04))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text("\(linkedGoalIds.count) selected")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - Target Count Section
    
    private var targetCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasTargetCount) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Target Count")
                        .font(.system(size: 11, weight: .medium))
                    Text("e.g., 'Complete 100 times'")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            
            if hasTargetCount {
                HStack(spacing: 12) {
                    Text("Target:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    TextField("", value: $targetCount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Text("completions")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                }
                .disabled(linkedGoalIds.isEmpty)
                .opacity(linkedGoalIds.isEmpty ? 0.5 : 1)
                
                if linkedGoalIds.isEmpty {
                    Text("Link at least one daily task above to use target count.")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Color picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(ProjectColorName.allCases) { color in
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
                    }
                }
            }
            
            // Icon picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button { selectedIcon = icon } label: {
                            let tint = ProjectColorName(rawValue: selectedColor)?.color ?? .blue
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIcon == icon ? tint.opacity(0.25) : Color.gray.opacity(0.08))
                                )
                                .foregroundStyle(selectedIcon == icon ? tint : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Preview
            VStack(alignment: .leading, spacing: 6) {
                Text("Preview")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 10) {
                    let color = ProjectColorName(rawValue: selectedColor)?.color ?? .blue
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: selectedIcon)
                            .font(.system(size: 14))
                            .foregroundStyle(color)
                    }
                    
                    Text(title.isEmpty ? "Project Name" : title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(title.isEmpty ? .secondary : .primary)
                    
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.03))
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadProject() {
        guard let project else { return }
        title = project.title
        description = project.description
        startDate = project.startDate
        hasDeadline = project.targetDate != nil
        targetDate = project.targetDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        linkedGoalIds = Set(project.linkedGoalIds)
        hasTargetCount = project.targetCount != nil
        targetCount = project.targetCount ?? 50
        selectedColor = project.colorName
        selectedIcon = project.icon
    }
    
    private func saveProject() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        if let existing = project {
            var updated = existing
            updated.title = trimmedTitle
            updated.description = description.trimmingCharacters(in: .whitespaces)
            updated.startDate = startDate
            updated.targetDate = hasDeadline ? targetDate : nil
            updated.linkedGoalIds = Array(linkedGoalIds)
            updated.targetCount = hasTargetCount && !linkedGoalIds.isEmpty ? max(1, targetCount) : nil
            updated.colorName = selectedColor
            updated.icon = selectedIcon
            dataStore.updateProject(updated)
        } else {
            let newProject = Project(
                title: trimmedTitle,
                description: description.trimmingCharacters(in: .whitespaces),
                startDate: startDate,
                targetDate: hasDeadline ? targetDate : nil,
                linkedGoalIds: Array(linkedGoalIds),
                targetCount: hasTargetCount && !linkedGoalIds.isEmpty ? max(1, targetCount) : nil,
                colorName: selectedColor,
                icon: selectedIcon
            )
            dataStore.addProject(newProject)
        }
        
        dismiss()
    }
}

#Preview("New Project") {
    ProjectEditorSheet(project: nil)
        .environment(DataStore())
        .frame(width: 480, height: 600)
}

#Preview("Edit Project") {
    let store = DataStore()
    let project = Project(
        title: "Learn Spanish",
        description: "Reach B2 level",
        startDate: Date(),
        targetDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
        targetCount: 100,
        colorName: "purple",
        icon: "globe"
    )
    store.addProject(project)
    
    return ProjectEditorSheet(project: project)
        .environment(store)
        .frame(width: 480, height: 600)
}
