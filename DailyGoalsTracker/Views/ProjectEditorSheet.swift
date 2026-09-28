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
            header
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    basicInfoSection
                    datesSection
                    Text("Link daily tasks and set targets on each milestone after saving.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            
            if GoalEntry.startOfCivilDay(for: startDate) > GoalEntry.startOfCivilDay(for: Date()) {
                Text("This project will appear under Upcoming until the start date.")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)
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
            updated.colorName = selectedColor
            updated.icon = selectedIcon
            dataStore.updateProject(updated)
        } else {
            let newProject = Project(
                title: trimmedTitle,
                description: description.trimmingCharacters(in: .whitespaces),
                startDate: startDate,
                targetDate: hasDeadline ? targetDate : nil,
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
        .frame(width: 480, height: 560)
}

#Preview("Edit Project") {
    let store = DataStore()
    let project = Project(
        title: "Learn Spanish",
        description: "Reach B2 level",
        startDate: Date(),
        targetDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
        colorName: "purple",
        icon: "globe"
    )
    store.addProject(project)
    
    return ProjectEditorSheet(project: project)
        .environment(store)
        .frame(width: 480, height: 560)
}
