import SwiftUI

/// Grouped form for creating or editing a project’s name, dates, icon, and color.
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
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text(isEditing ? "Edit Project" : "New Project")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") { saveProject() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            Form {
                Section {
                    TextField("Name", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Timeline") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    Toggle("Target Date", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker(
                            "Deadline",
                            selection: $targetDate,
                            in: startDate...,
                            displayedComponents: .date
                        )
                    }
                    if GoalEntry.startOfCivilDay(for: startDate) > GoalEntry.startOfCivilDay(for: Date()) {
                        Text("This project stays under Upcoming until the start date.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Appearance") {
                    colorPicker
                    iconPicker
                    previewRow
                }
                
                Section {
                    Text("Link daily tasks and set targets on each milestone after saving.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 560)
        .onAppear(perform: loadProject)
    }
    
    private var colorPicker: some View {
        HStack {
            Text("Color")
            Spacer()
            HStack(spacing: 8) {
                ForEach(ProjectColorName.allCases) { color in
                    Button {
                        selectedColor = color.rawValue
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if selectedColor == color.rawValue {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(color.rawValue.capitalized)
                }
            }
        }
    }
    
    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(iconOptions, id: \.self) { icon in
                    Button { selectedIcon = icon } label: {
                        Image(systemName: icon)
                            .font(.body)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                            )
                            .foregroundStyle(selectedIcon == icon ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var previewRow: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedIcon)
                .font(.title3)
                .foregroundStyle(ProjectColorName(rawValue: selectedColor)?.color ?? .accentColor)
                .frame(width: 28, height: 28)
            Text(title.isEmpty ? "Project Name" : title)
                .font(.body)
                .foregroundStyle(title.isEmpty ? .secondary : .primary)
            Spacer()
        }
    }
    
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
}
