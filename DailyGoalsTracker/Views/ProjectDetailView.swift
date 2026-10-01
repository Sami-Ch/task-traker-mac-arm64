import SwiftUI

/// Detail view for a single project. Used in Settings.
struct ProjectDetailView: View {
    @Environment(DataStore.self) private var dataStore
    
    let project: Project
    let onBack: () -> Void
    
    @State private var showingEditor = false
    @State private var newMilestoneTitle = ""
    @State private var showPlanEditor = false
    @State private var linkingMilestone: LinkingSheet?
    @State private var editingTargetLink: TargetEditSheet?
    @State private var alertEditor: AlertEditorSheet?
    
    private var currentProject: Project {
        dataStore.project(for: project.id) ?? project
    }
    
    private var progress: ProjectProgress {
        dataStore.projectProgress(for: currentProject)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                BackLinkButton(title: "Projects", helpText: "Back to projects", action: onBack)
                
                header
                
                if currentProject.isUpcoming {
                    upcomingNote
                }
                
                progressSection
                
                if !currentProject.description.isEmpty {
                    descriptionSection
                }
                
                milestonesSection
                alertsSection
                planSection
                actionsSection
            }
            .padding(20)
        }
        .onAppear {
            dataStore.syncMilestoneAutoComplete(projectId: currentProject.id)
        }
        .sheet(isPresented: $showingEditor) {
            ProjectEditorSheet(project: currentProject)
        }
        .sheet(item: $linkingMilestone) { sheet in
            MilestoneGoalPickerSheet(
                projectId: currentProject.id,
                milestoneId: sheet.milestoneId,
                alreadyLinked: Set(
                    currentProject.milestones
                        .first { $0.id == sheet.milestoneId }?
                        .linkedGoalIds ?? []
                )
            )
            .frame(width: 400, height: 480)
        }
        .sheet(item: $editingTargetLink) { edit in
            MilestoneTargetEditorSheet(
                projectId: edit.projectId,
                milestoneId: edit.milestoneId,
                linkId: edit.linkId,
                initialTarget: edit.initialTarget
            )
            .frame(width: 360, height: 220)
        }
        .sheet(item: $alertEditor) { sheet in
            ProjectAlertEditorSheet(
                project: currentProject,
                existing: sheet.existing,
                initialMilestoneId: sheet.initialMilestoneId
            )
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: currentProject.icon)
                .font(.title2)
                .foregroundStyle(currentProject.color)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(currentProject.title)
                    .font(.headline)
                
                HStack(spacing: 6) {
                    Text(statusLabel)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                    if let label = currentProject.deadlineLabel() {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(label.text)
                            .font(.subheadline)
                            .foregroundStyle(label.color)
                    }
                }
            }
            
            Spacer()
            
            Button("Edit") {
                showingEditor = true
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var statusLabel: String {
        if currentProject.isUpcoming { return "Upcoming" }
        return currentProject.status.title
    }
    
    private var statusColor: Color {
        if currentProject.isUpcoming { return .secondary }
        switch currentProject.status {
        case .completed: return .green
        case .paused: return .orange
        case .archived: return .secondary
        case .active: return .secondary
        }
    }
    
    private var upcomingNote: some View {
        Text("Starts on \(currentProject.startDate, style: .date). Daily-task counting begins then.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    
    // MARK: - Progress
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
            
            if currentProject.isUpcoming {
                Text("Not started")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(progress.overallProgressPercent)%")
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(currentProject.isCompleted ? .green : .primary)
            }
            
            if currentProject.hasMilestones {
                Text(
                    currentProject.isUpcoming
                        ? "\(progress.totalMilestones) milestones"
                        : "\(progress.completedMilestones) of \(progress.totalMilestones) milestones"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(currentProject.isCompleted ? Color.green : Color.accentColor)
                        .frame(
                            width: geo.size.width * (currentProject.isUpcoming ? 0 : progress.overallProgress),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.headline)
            Text(currentProject.description)
                .font(.body)
        }
    }
    
    // MARK: - Milestones
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.headline)
            
            if currentProject.milestones.isEmpty {
                Text("Break the project into steps. Link a daily task to a milestone to count progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(currentProject.milestones.sorted { $0.order < $1.order }) { milestone in
                MilestoneDetailCard(
                    milestone: milestone,
                    project: currentProject,
                    detail: progress.detail(for: milestone.id),
                    milestoneAlerts: currentProject.alerts(forMilestoneId: milestone.id),
                    onToggle: {
                        dataStore.toggleProjectMilestone(
                            projectId: currentProject.id,
                            milestoneId: milestone.id
                        )
                    },
                    onDelete: {
                        dataStore.removeMilestone(
                            from: currentProject.id,
                            milestoneId: milestone.id
                        )
                    },
                    onAddGoal: {
                        linkingMilestone = LinkingSheet(milestoneId: milestone.id)
                    },
                    onRemoveLink: { linkId in
                        dataStore.removeGoalLink(
                            from: currentProject.id,
                            milestoneId: milestone.id,
                            linkId: linkId
                        )
                    },
                    onEditTarget: { link in
                        editingTargetLink = TargetEditSheet(
                            projectId: currentProject.id,
                            milestoneId: milestone.id,
                            linkId: link.id,
                            initialTarget: link.targetCount
                        )
                    },
                    onAddAlert: {
                        alertEditor = AlertEditorSheet(initialMilestoneId: milestone.id)
                    },
                    onEditAlert: { alert in
                        alertEditor = AlertEditorSheet(existing: alert)
                    },
                    onToggleAlert: { alertId in
                        dataStore.toggleAlert(projectId: currentProject.id, alertId: alertId)
                    },
                    onDeleteAlert: { alertId in
                        dataStore.deleteAlert(projectId: currentProject.id, alertId: alertId)
                    }
                )
            }
            
            HStack(spacing: 8) {
                TextField("Add milestone", text: $newMilestoneTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addMilestone() }
                Button("Add") { addMilestone() }
                    .disabled(newMilestoneTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    private func addMilestone() {
        let title = newMilestoneTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        dataStore.addMilestone(to: currentProject.id, title: title)
        newMilestoneTitle = ""
    }
    
    // MARK: - Alerts
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Alerts")
                    .font(.headline)
                Spacer()
                Button("Add") {
                    alertEditor = AlertEditorSheet()
                }
            }
            
            let projectAlerts = currentProject.projectScopedAlerts
            if projectAlerts.isEmpty {
                Text("Hourly, daily, or deadline reminders for this project.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(projectAlerts) { alert in
                    ProjectAlertRow(
                        alert: alert,
                        project: currentProject,
                        onToggle: {
                            dataStore.toggleAlert(projectId: currentProject.id, alertId: alert.id)
                        },
                        onEdit: {
                            alertEditor = AlertEditorSheet(existing: alert)
                        },
                        onDelete: {
                            dataStore.deleteAlert(projectId: currentProject.id, alertId: alert.id)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Plan
    
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Plan")
                    .font(.headline)
                Spacer()
                Button(showPlanEditor ? "Done" : "Edit") {
                    showPlanEditor.toggle()
                }
            }
            
            if showPlanEditor {
                TextEditor(text: Binding(
                    get: { currentProject.plan },
                    set: { newValue in
                        var updated = currentProject
                        updated.plan = newValue
                        dataStore.updateProject(updated)
                    }
                ))
                .font(.body)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            } else if currentProject.plan.isEmpty {
                Text("No plan yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(JournalMarkdown.plainText(from: currentProject.plan))
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Actions
    
    private var actionsSection: some View {
        HStack(spacing: 12) {
            if currentProject.isCompleted {
                Button("Reopen") {
                    dataStore.reopenProject(currentProject.id)
                }
            } else if currentProject.isPaused {
                Button("Resume") {
                    dataStore.reopenProject(currentProject.id)
                }
            } else if !currentProject.isUpcoming {
                Button("Pause") {
                    dataStore.pauseProject(currentProject.id)
                }
            }
            
            Spacer()
            
            if !currentProject.isCompleted {
                Button("Mark Complete") {
                    dataStore.completeProject(currentProject.id)
                    onBack()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Sheet Identifiers

private struct LinkingSheet: Identifiable {
    let milestoneId: UUID
    var id: UUID { milestoneId }
}

private struct TargetEditSheet: Identifiable {
    let projectId: UUID
    let milestoneId: UUID
    let linkId: UUID
    let initialTarget: Int?
    
    var id: UUID { linkId }
}

private struct AlertEditorSheet: Identifiable {
    let id = UUID()
    var existing: ProjectAlert? = nil
    var initialMilestoneId: UUID? = nil
}

// MARK: - Alert Row

struct ProjectAlertRow: View {
    let alert: ProjectAlert
    let project: Project
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: alert.isEnabled ? "bell.fill" : "bell.slash")
                    .font(.body)
                    .foregroundStyle(alert.isEnabled ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(alert.isEnabled ? "Disable" : "Enable")
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.displayTitle(project: project))
                    .font(.body)
                    .lineLimit(1)
                Text(alert.schedule.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(alert.sound.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .opacity(alert.isEnabled ? 1 : 0.6)
    }
}

// MARK: - Milestone Detail Card

struct MilestoneDetailCard: View {
    @Environment(DataStore.self) private var dataStore
    
    let milestone: Milestone
    let project: Project
    let detail: MilestoneProgress?
    let milestoneAlerts: [ProjectAlert]
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onAddGoal: () -> Void
    let onRemoveLink: (UUID) -> Void
    let onEditTarget: (MilestoneGoalLink) -> Void
    let onAddAlert: () -> Void
    let onEditAlert: (ProjectAlert) -> Void
    let onToggleAlert: (UUID) -> Void
    let onDeleteAlert: (UUID) -> Void
    
    private var isComplete: Bool {
        detail?.isEffectivelyComplete ?? milestone.isCompleted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isComplete ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle complete")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title)
                        .font(.body)
                        .strikethrough(isComplete, color: .secondary)
                        .foregroundStyle(isComplete ? .secondary : .primary)
                        .lineLimit(1)
                    
                    if let detail, detail.targetsTotalCount > 0, project.hasStarted {
                        Text("\(detail.targetsMetCount) of \(detail.targetsTotalCount) targets met")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if milestone.hasLinkedGoals {
                        Text("\(milestone.linkedGoals.count) linked task\(milestone.linkedGoals.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if let date = milestone.completedAt, isComplete {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete milestone")
            }
            .frame(minHeight: 44)
            
            ForEach(milestone.linkedGoals) { link in
                linkedGoalRow(link)
            }
            
            ForEach(milestoneAlerts) { alert in
                ProjectAlertRow(
                    alert: alert,
                    project: project,
                    onToggle: { onToggleAlert(alert.id) },
                    onEdit: { onEditAlert(alert) },
                    onDelete: { onDeleteAlert(alert.id) }
                )
            }
            
            HStack(spacing: 8) {
                Button("Link daily task", action: onAddGoal)
                Button("Alert", action: onAddAlert)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func linkedGoalRow(_ link: MilestoneGoalLink) -> some View {
        let goal = dataStore.goals.first { $0.id == link.goalId }
        let count = detail?.goalProgress.first { $0.linkId == link.id }?.count ?? 0
        
        HStack(spacing: 8) {
            if let goal {
                GoalIconView(icon: goal.icon, size: 12, isActive: goal.isActive)
                Text(goal.title)
                    .font(.body)
                    .lineLimit(1)
            } else {
                Text("Missing task")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if project.hasStarted {
                if let target = link.targetCount, target > 0 {
                    Text(formatCount(count) + "/\(target)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(count + 0.0001 >= Double(target) ? .green : .secondary)
                } else {
                    Text(formatCount(count))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else if let target = link.targetCount, target > 0 {
                Text("Target \(target)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button("Target") {
                onEditTarget(link)
            }
            Button("Remove", role: .destructive) {
                onRemoveLink(link.id)
            }
        }
        .frame(minHeight: 44)
    }
    
    private func formatCount(_ value: Double) -> String {
        if value == floor(value) {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Goal Picker Sheet

struct MilestoneGoalPickerSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let projectId: UUID
    let milestoneId: UUID
    let alreadyLinked: Set<UUID>
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text("Link Daily Task")
                    .font(.headline)
                Spacer()
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            List {
                let available = dataStore.goals.filter { $0.isActive && !alreadyLinked.contains($0.id) }
                if available.isEmpty {
                    Text("No more daily tasks to link.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(available) { goal in
                        Button {
                            dataStore.addGoalLink(
                                to: projectId,
                                milestoneId: milestoneId,
                                goalId: goal.id
                            )
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                GoalIconView(icon: goal.icon, size: 14, isActive: true)
                                Text(goal.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - Target Editor Sheet

struct MilestoneTargetEditorSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let projectId: UUID
    let milestoneId: UUID
    let linkId: UUID
    let initialTarget: Int?
    
    @State private var hasTarget = false
    @State private var targetValue = 30
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Target")
                .font(.headline)
            
            Toggle("Set target count", isOn: $hasTarget)
            
            if hasTarget {
                HStack {
                    Text("Target")
                    TextField("", value: $targetValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("completions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            
            Text("Partial days count as 0.5. Leave off to track without a target.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    dataStore.updateGoalLinkTarget(
                        projectId: projectId,
                        milestoneId: milestoneId,
                        linkId: linkId,
                        targetCount: hasTarget ? max(1, targetValue) : nil
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear {
            hasTarget = (initialTarget ?? 0) > 0
            targetValue = initialTarget ?? 30
        }
    }
}

#Preview("Project Detail") {
    let store = DataStore()
    let project = Project(
        title: "Learn Spanish",
        description: "Reach B2 level in Spanish through daily practice and structured learning.",
        plan: "## Phase 1: Foundation\n- Duolingo daily\n- Anki flashcards",
        startDate: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
        targetDate: Calendar.current.date(byAdding: .month, value: 4, to: Date()),
        milestones: [
            Milestone(title: "Complete A1 level", isCompleted: true, completedAt: Date(), order: 0),
            Milestone(title: "30-day streak", order: 1),
            Milestone(title: "Watch first movie in Spanish", order: 2)
        ],
        colorName: "purple",
        icon: "globe"
    )
    store.addProject(project)
    
    return ProjectDetailView(project: project, onBack: {})
        .environment(store)
        .frame(width: 560, height: 600)
}
