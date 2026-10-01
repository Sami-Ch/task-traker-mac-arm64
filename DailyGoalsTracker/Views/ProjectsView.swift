import SwiftUI

/// Status list for the popover. Management lives in Settings.
struct ProjectsView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(SettingsRouter.self) private var settingsRouter
    
    @State private var previewedProjectId: UUID?
    @State private var showCompletedSection = false
    
    var body: some View {
        Group {
            if let previewedProjectId, let project = dataStore.project(for: previewedProjectId) {
                ProjectStatusSummary(project: project) {
                    self.previewedProjectId = nil
                } onManage: {
                    settingsRouter.showProject(project.id)
                    NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
                }
            } else {
                projectList
            }
        }
        .onAppear {
            for project in dataStore.projects where project.hasStarted {
                dataStore.syncMilestoneAutoComplete(projectId: project.id)
            }
        }
    }
    
    private var projectList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !dataStore.activeProjects.isEmpty {
                    projectSection(title: "Active", projects: dataStore.activeProjects)
                }
                if !dataStore.upcomingProjects.isEmpty {
                    projectSection(title: "Upcoming", projects: dataStore.upcomingProjects)
                }
                if !dataStore.pausedProjects.isEmpty {
                    projectSection(title: "Paused", projects: dataStore.pausedProjects)
                }
                if !dataStore.completedProjects.isEmpty {
                    completedSection
                }
                if dataStore.projects.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private func projectSection(title: String, projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(title) · \(projects.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            
            ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                if index > 0 {
                    Divider()
                }
                ProjectStatusRow(
                    project: project,
                    progress: dataStore.projectProgress(for: project),
                    momentum: dataStore.projectMomentum(for: project)
                ) {
                    previewedProjectId = project.id
                }
            }
        }
    }
    
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCompletedSection.toggle()
                }
            } label: {
                HStack {
                    Text("Completed · \(dataStore.completedProjects.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showCompletedSection ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
            
            if showCompletedSection {
                ForEach(Array(dataStore.completedProjects.enumerated()), id: \.element.id) { index, project in
                    if index > 0 {
                        Divider()
                    }
                    ProjectStatusRow(
                        project: project,
                        progress: dataStore.projectProgress(for: project),
                        momentum: dataStore.projectMomentum(for: project)
                    ) {
                        previewedProjectId = project.id
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No Projects Yet")
                .font(.headline)
            Text("Add a project in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                settingsRouter.showProjects()
                NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct ProjectStatusRow: View {
    let project: Project
    let progress: ProjectProgress
    let momentum: ProjectMomentum
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: project.icon)
                    .font(.body)
                    .foregroundStyle(project.color)
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                trailing
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
    
    private var subtitle: String {
        if let next = project.nextMilestone, !project.isCompleted {
            return next.title
        }
        if let label = project.deadlineLabel() {
            return label.text
        }
        return ""
    }
    
    private var subtitleColor: Color {
        if project.nextMilestone != nil, !project.isCompleted {
            return .secondary
        }
        return project.deadlineLabel()?.color ?? .secondary
    }
    
    @ViewBuilder
    private var trailing: some View {
        if project.isUpcoming {
            Text("Not started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    MiniProgressRing(progress: progress.overallProgress, size: 14)
                    Text("\(progress.overallProgressPercent)%")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(project.isCompleted ? .green : .secondary)
                }
                if momentum.streak > 0 {
                    Text("\(momentum.streak)d")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Read-only summary in the popover. Manage opens Settings.
struct ProjectStatusSummary: View {
    @Environment(DataStore.self) private var dataStore
    let project: Project
    let onBack: () -> Void
    let onManage: () -> Void
    
    private var current: Project {
        dataStore.project(for: project.id) ?? project
    }
    
    private var progress: ProjectProgress {
        dataStore.projectProgress(for: current)
    }
    
    private var momentum: ProjectMomentum {
        dataStore.projectMomentum(for: current)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BackLinkButton(title: "Projects", action: onBack)
                    
                    header
                    tracker
                    if !current.description.isEmpty {
                        detailBlock(title: "About") {
                            Text(current.description)
                                .font(.body)
                        }
                    }
                    facts
                    if current.hasLinkedGoals {
                        linkedTasks
                    }
                    if current.hasMilestones {
                        milestones
                    }
                }
                .padding(16)
            }
            
            Divider()
            
            Button("Manage", action: onManage)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: current.icon)
                .font(.title3)
                .foregroundStyle(current.color)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(current.title)
                    .font(.headline)
                if let label = current.deadlineLabel() {
                    Text(label.text)
                        .font(.subheadline)
                        .foregroundStyle(label.color)
                }
            }
        }
    }
    
    private var tracker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(progress.overallProgressPercent)%")
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(current.isCompleted ? .green : .primary)
                    .contentTransition(.numericText())
                Spacer()
                if momentum.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                        Text("\(momentum.streak)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                    .help("Days in a row with a linked daily task")
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(current.isCompleted ? Color.green : Color.accentColor)
                        .frame(width: geo.size.width * progress.overallProgress)
                }
            }
            .frame(height: 6)
            
            if !momentum.recentDays.isEmpty, momentum.linkedTaskCount > 0 {
                HStack(spacing: 6) {
                    ForEach(momentum.recentDays) { mark in
                        Capsule()
                            .fill(dayColor(mark.kind))
                            .frame(height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            Text(momentum.encouragement)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func dayColor(_ kind: ProjectMomentum.DayKind) -> Color {
        switch kind {
        case .done: return .green
        case .partial: return .orange
        case .missed: return .red.opacity(0.7)
        case .skipped, .none: return Color.primary.opacity(0.08)
        }
    }
    
    private var facts: some View {
        VStack(alignment: .leading, spacing: 8) {
            if current.hasMilestones {
                labeled("Milestones", "\(progress.completedMilestones) of \(progress.totalMilestones)")
            }
            labeled("Daily tasks", momentum.linkedTaskCount == 0
                    ? "None linked"
                    : "\(momentum.linkedTaskCount) linked")
            labeled("Time", timeFact)
            if !current.alerts.isEmpty {
                let on = current.alerts.filter(\.isEnabled).count
                labeled("Alerts", "\(on) of \(current.alerts.count) on")
            }
        }
    }
    
    private var timeFact: String {
        if current.isUpcoming {
            return "Not started"
        }
        if current.isCompleted {
            return "Completed"
        }
        if momentum.daysSinceStart == 0 {
            return "Started today"
        }
        if momentum.daysSinceStart == 1 {
            return "1 day in"
        }
        return "\(momentum.daysSinceStart) days in"
    }
    
    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
        .frame(minHeight: 28)
    }
    
    private var linkedTasks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked tasks")
                .font(.headline)
            ForEach(linkedRows, id: \.id) { row in
                HStack {
                    GoalIconView(icon: row.icon, size: 12, isActive: true)
                    Text(row.title)
                        .font(.body)
                        .lineLimit(1)
                    Spacer()
                    Text(row.detail)
                        .font(.subheadline)
                        .foregroundStyle(row.met ? .green : .secondary)
                }
                .frame(minHeight: 36)
            }
        }
    }
    
    private var linkedRows: [LinkedTaskRow] {
        current.milestones
            .sorted { $0.order < $1.order }
            .flatMap { milestone in
                let detail = progress.detail(for: milestone.id)
                return milestone.linkedGoals.map { link in
                    let goal = dataStore.goals.first { $0.id == link.goalId }
                    let count = detail?.goalProgress.first { $0.linkId == link.id }?.count ?? 0
                    let met = link.targetCount.map { count + 0.0001 >= Double($0) } ?? false
                    let countText = count == floor(count) ? "\(Int(count))" : String(format: "%.1f", count)
                    let detailText: String
                    if let target = link.targetCount, target > 0 {
                        detailText = "\(countText)/\(target)"
                    } else {
                        detailText = countText
                    }
                    return LinkedTaskRow(
                        id: link.id,
                        title: goal?.title ?? "Missing task",
                        icon: goal?.icon ?? "questionmark.circle",
                        detail: detailText,
                        met: met
                    )
                }
            }
    }
    
    private var milestones: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Milestones")
                .font(.headline)
            ForEach(current.milestones.sorted { $0.order < $1.order }) { milestone in
                let done = progress.detail(for: milestone.id)?.isEffectivelyComplete ?? milestone.isCompleted
                HStack(spacing: 10) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done ? .green : .secondary)
                    Text(milestone.title)
                        .font(.body)
                        .strikethrough(done, color: .secondary)
                        .foregroundStyle(done ? .secondary : .primary)
                    Spacer()
                }
                .frame(minHeight: 36)
            }
        }
    }
    
    private func detailBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

private struct LinkedTaskRow: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let detail: String
    let met: Bool
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
        .environment(SettingsRouter())
        .frame(width: 400, height: 600)
}
