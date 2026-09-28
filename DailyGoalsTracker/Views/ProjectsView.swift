import SwiftUI

/// Main projects list view - replaces PlanningView
struct ProjectsView: View {
    @Environment(DataStore.self) private var dataStore
    
    @State private var showingAddProject = false
    @State private var selectedProject: Project?
    @State private var showCompletedSection = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if dataStore.hasPlanningGoalsToMigrate {
                    migrationBanner
                }
                
                if !dataStore.projects.isEmpty {
                    newProjectButton
                }
                
                if !dataStore.activeProjects.isEmpty {
                    projectSection(
                        title: "Active",
                        icon: "play.circle.fill",
                        color: .blue,
                        projects: dataStore.activeProjects
                    )
                }
                
                if !dataStore.upcomingProjects.isEmpty {
                    projectSection(
                        title: "Upcoming",
                        icon: "calendar",
                        color: .purple,
                        projects: dataStore.upcomingProjects,
                        isUpcoming: true
                    )
                }
                
                if !dataStore.pausedProjects.isEmpty {
                    projectSection(
                        title: "Paused",
                        icon: "pause.circle.fill",
                        color: .orange,
                        projects: dataStore.pausedProjects
                    )
                }
                
                if !dataStore.completedProjects.isEmpty {
                    completedSection
                }
                
                if dataStore.projects.isEmpty && !dataStore.hasPlanningGoalsToMigrate {
                    emptyState
                }
            }
            .padding(16)
        }
        .onAppear {
            for project in dataStore.projects where project.hasStarted {
                dataStore.syncMilestoneAutoComplete(projectId: project.id)
            }
        }
        .sheet(isPresented: $showingAddProject) {
            ProjectEditorSheet(project: nil)
                .frame(width: 480, height: 600)
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project)
                .frame(width: 480, height: 600)
        }
    }
    
    // MARK: - New Project
    
    private var newProjectButton: some View {
        Button {
            showingAddProject = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                Text("New Project")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Section
    
    private func projectSection(
        title: String,
        icon: String,
        color: Color,
        projects: [Project],
        isUpcoming: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(projects.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            
            ForEach(projects) { project in
                ProjectCard(
                    project: project,
                    progress: dataStore.projectProgress(for: project),
                    onTap: { selectedProject = project },
                    isUpcoming: isUpcoming
                )
            }
        }
    }
    
    // MARK: - Completed Section
    
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showCompletedSection.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Text("Completed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(dataStore.completedProjects.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Image(systemName: showCompletedSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showCompletedSection {
                ForEach(dataStore.completedProjects) { project in
                    ProjectCard(
                        project: project,
                        progress: dataStore.projectProgress(for: project),
                        onTap: { selectedProject = project },
                        isCompleted: true
                    )
                }
            }
        }
    }
    
    // MARK: - Migration Banner
    
    private var migrationBanner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import from Old Planning")
                        .font(.system(size: 12, weight: .semibold))
                    Text("You have \(dataStore.planningGoalsCount) planning goal\(dataStore.planningGoalsCount == 1 ? "" : "s") from the old system.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dataStore.migratePlanningGoalsToProjects()
                    }
                } label: {
                    Text("Import All")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
                
                Button {
                    dataStore.planningGoals.removeAll()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .font(.system(size: 40))
                .foregroundStyle(.purple.opacity(0.5))
            
            Text("No Projects Yet")
                .font(.headline)
            
            Text("Create a project with milestones.\nLink daily tasks on each milestone to track progress.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddProject = true
            } label: {
                Label("New Project", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: Project
    let progress: ProjectProgress
    let onTap: () -> Void
    var isCompleted: Bool = false
    var isUpcoming: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(project.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: project.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(project.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        
                        if isUpcoming {
                            Text("Starts \(project.startDate, style: .date)")
                                .font(.system(size: 10))
                                .foregroundStyle(.purple)
                        } else if let deadline = project.targetDate {
                            Text(deadlineText(deadline))
                                .font(.system(size: 10))
                                .foregroundStyle(deadlineColor(deadline))
                        } else {
                            Text("Started \(project.startDate, style: .date)")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)
                        
                        if !isUpcoming {
                            Capsule()
                                .fill(isCompleted ? Color.green : project.color)
                                .frame(width: geo.size.width * progress.overallProgress, height: 6)
                        }
                    }
                }
                .frame(height: 6)
                
                HStack(spacing: 12) {
                    if project.hasMilestones {
                        statPill(
                            icon: "flag.checkered",
                            text: isUpcoming
                                ? "\(progress.totalMilestones) milestones"
                                : "\(progress.completedMilestones)/\(progress.totalMilestones)",
                            color: .green
                        )
                    }
                    
                    if project.hasLinkedGoals {
                        statPill(
                            icon: "link",
                            text: "\(project.allLinkedGoalIds.count) tasks",
                            color: .blue
                        )
                    }
                    
                    Spacer()
                    
                    if isUpcoming {
                        Text("Not started")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.purple.opacity(0.8))
                    } else {
                        Text("\(progress.overallProgressPercent)%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(isCompleted ? .green : project.color)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(project.color.opacity(isUpcoming ? 0.25 : 0.15), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .opacity(isCompleted ? 0.7 : (isUpcoming ? 0.85 : 1))
    }
    
    private func statPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color.opacity(0.8))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1), in: Capsule())
    }
    
    private func deadlineText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 {
            return "Overdue by \(-days) days"
        } else if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else if days <= 7 {
            return "Due in \(days) days"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Due \(formatter.string(from: date))"
        }
    }
    
    private func deadlineColor(_ date: Date) -> Color {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 {
            return .red
        } else if days <= 7 {
            return .orange
        }
        return .secondary
    }
}

#Preview("Projects View") {
    let store = DataStore()
    store.addProject(Project(
        title: "Learn Spanish",
        description: "Reach B2 level",
        startDate: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
        targetDate: Calendar.current.date(byAdding: .month, value: 4, to: Date()),
        milestones: [
            Milestone(title: "Complete A1", isCompleted: true, order: 0),
            Milestone(title: "Complete A2", order: 1),
            Milestone(title: "Complete B1", order: 2)
        ],
        colorName: "purple",
        icon: "globe"
    ))
    
    return ProjectsView()
        .environment(store)
        .frame(width: 400, height: 600)
}
