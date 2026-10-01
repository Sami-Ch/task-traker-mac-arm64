import SwiftUI

/// Create and manage projects. The popover only shows status.
struct ProjectsSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(SettingsRouter.self) private var settingsRouter
    
    @State private var openedProjectId: UUID?
    @State private var showingNewProject = false
    
    var body: some View {
        Group {
            if let openedProjectId, let project = dataStore.project(for: openedProjectId) {
                ProjectDetailView(project: project) {
                    self.openedProjectId = nil
                }
            } else {
                projectList
            }
        }
        .onAppear(perform: openPendingProject)
        .onChange(of: settingsRouter.projectIdToOpen) { _, _ in
            openPendingProject()
        }
        .sheet(isPresented: $showingNewProject) {
            ProjectEditorSheet(project: nil)
        }
    }
    
    private var projectList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(dataStore.activeProjects.count) active · \(dataStore.projects.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    showingNewProject = true
                } label: {
                    Label("New Project", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            if dataStore.projects.isEmpty {
                emptyState
            } else {
                List {
                    projectSection("Active", dataStore.activeProjects)
                    projectSection("Upcoming", dataStore.upcomingProjects)
                    projectSection("Paused", dataStore.pausedProjects)
                    projectSection("Completed", dataStore.completedProjects)
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Projects")
    }
    
    @ViewBuilder
    private func projectSection(_ title: String, _ projects: [Project]) -> some View {
        if !projects.isEmpty {
            Section(title) {
                ForEach(projects) { project in
                    Button {
                        openedProjectId = project.id
                    } label: {
                        SettingsProjectRow(
                            project: project,
                            progress: dataStore.projectProgress(for: project)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete…", role: .destructive) {
                            dataStore.deleteProject(project)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No Projects Yet")
                .font(.headline)
            Text("Create a project to track a longer goal against daily tasks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("New Project") {
                showingNewProject = true
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func openPendingProject() {
        guard let id = settingsRouter.projectIdToOpen else { return }
        openedProjectId = id
        settingsRouter.clearProjectOpen()
    }
}

struct SettingsProjectRow: View {
    let project: Project
    let progress: ProjectProgress
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: project.icon)
                .font(.body)
                .foregroundStyle(project.color)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let label = project.deadlineLabel() {
                    Text(label.text)
                        .font(.caption)
                        .foregroundStyle(label.color)
                }
            }
            
            Spacer(minLength: 8)
            
            if project.isUpcoming {
                Text("Not started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(progress.overallProgressPercent)%")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(project.isCompleted ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
    }
}

#Preview("Projects Settings") {
    let store = DataStore()
    store.addProject(Project(
        title: "Learn Spanish",
        startDate: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
        targetDate: Calendar.current.date(byAdding: .month, value: 4, to: Date()),
        colorName: "purple",
        icon: "globe"
    ))
    
    return ProjectsSettingsPane()
        .environment(store)
        .environment(SettingsRouter())
        .frame(width: 560, height: 480)
}
