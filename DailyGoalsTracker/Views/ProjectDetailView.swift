import SwiftUI

/// Detail view for a single project
struct ProjectDetailView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    
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
        VStack(spacing: 0) {
            header
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if currentProject.isUpcoming {
                        upcomingBanner
                    }
                    
                    progressSection
                    
                    if !currentProject.description.isEmpty {
                        descriptionSection
                    }
                    
                    milestonesSection
                    
                    alertsSection
                    
                    planSection
                }
                .padding(16)
            }
            
            Divider()
            
            actionsFooter
        }
        .onAppear {
            dataStore.syncMilestoneAutoComplete(projectId: currentProject.id)
        }
        .sheet(isPresented: $showingEditor) {
            ProjectEditorSheet(project: currentProject)
                .frame(width: 480, height: 560)
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
            .frame(width: 320, height: 200)
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
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            ZStack {
                Circle()
                    .fill(currentProject.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: currentProject.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(currentProject.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(currentProject.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if currentProject.isUpcoming {
                        Text("Upcoming")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.purple)
                    } else {
                        Text(currentProject.status.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(currentProject.status.color)
                    }
                    
                    Text("·")
                        .foregroundStyle(.tertiary)
                    
                    if currentProject.isUpcoming {
                        Text("Starts \(currentProject.startDate, style: .date)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else if let deadline = currentProject.targetDate {
                        Text("Due \(deadline, style: .date)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Started \(currentProject.startDate, style: .date)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button { showingEditor = true } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.blue.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Edit project")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Upcoming Banner
    
    private var upcomingBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16))
                .foregroundStyle(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Starts on \(currentProject.startDate, style: .date)")
                    .font(.system(size: 12, weight: .semibold))
                Text("Daily-task counting begins on the start date.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.purple.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 10)
                    
                    Capsule()
                        .fill(currentProject.isCompleted ? Color.green : currentProject.color)
                        .frame(
                            width: geo.size.width * (currentProject.isUpcoming ? 0 : progress.overallProgress),
                            height: 10
                        )
                }
            }
            .frame(height: 10)
            
            HStack(spacing: 16) {
                if currentProject.hasMilestones {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Milestones")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 4) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 10))
                            Text(
                                currentProject.isUpcoming
                                    ? "\(progress.totalMilestones)"
                                    : "\(progress.completedMilestones)/\(progress.totalMilestones)"
                            )
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Overall")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    if currentProject.isUpcoming {
                        Text("—")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(progress.overallProgressPercent)%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(currentProject.isCompleted ? .green : currentProject.color)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Text(currentProject.description)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.9))
        }
    }
    
    // MARK: - Milestones Section
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Milestones")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if currentProject.hasMilestones && !currentProject.isUpcoming {
                    Text("\(progress.completedMilestones)/\(progress.totalMilestones) complete")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
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
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.green.opacity(0.6))
                
                TextField("Add milestone...", text: $newMilestoneTitle)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .onSubmit { addMilestone() }
                
                if !newMilestoneTitle.isEmpty {
                    Button(action: addMilestone) {
                        Text("Add")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.06))
            )
        }
    }
    
    private func addMilestone() {
        let title = newMilestoneTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        dataStore.addMilestone(to: currentProject.id, title: title)
        newMilestoneTitle = ""
    }
    
    // MARK: - Alerts Section
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Alerts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    alertEditor = AlertEditorSheet()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 10))
                        Text("Add")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            
            let projectAlerts = currentProject.projectScopedAlerts
            if projectAlerts.isEmpty {
                Text("No project alerts. Add hourly, daily, or deadline reminders.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
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
    
    // MARK: - Plan Section
    
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Plan & Notes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showPlanEditor.toggle()
                } label: {
                    Text(showPlanEditor ? "Done" : "Edit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            if showPlanEditor {
                planEditorView
            } else {
                planPreviewView
            }
        }
    }
    
    private var planEditorView: some View {
        VStack(spacing: 0) {
            TextEditor(text: Binding(
                get: { currentProject.plan },
                set: { newValue in
                    var updated = currentProject
                    updated.plan = newValue
                    dataStore.updateProject(updated)
                }
            ))
            .font(.system(size: 12, design: .monospaced))
            .frame(minHeight: 120)
            .scrollContentBackground(.hidden)
            .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var planPreviewView: some View {
        Group {
            if currentProject.plan.isEmpty {
                Text("No plan or notes yet. Tap Edit to add.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            } else {
                Text(JournalMarkdown.plainText(from: currentProject.plan))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.02))
        )
    }
    
    // MARK: - Actions Footer
    
    private var actionsFooter: some View {
        HStack(spacing: 12) {
            if currentProject.isCompleted {
                Button {
                    dataStore.reopenProject(currentProject.id)
                } label: {
                    Label("Reopen", systemImage: "arrow.uturn.left")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            } else if currentProject.isPaused {
                Button {
                    dataStore.reopenProject(currentProject.id)
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            } else if !currentProject.isUpcoming {
                Button {
                    dataStore.pauseProject(currentProject.id)
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }
            
            Spacer()
            
            if !currentProject.isCompleted {
                Button {
                    dataStore.completeProject(currentProject.id)
                    dismiss()
                } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
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
                    .font(.system(size: 12))
                    .foregroundStyle(alert.isEnabled ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(alert.isEnabled ? "Disable" : "Enable")
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.displayTitle(project: project))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(alert.schedule.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(alert.sound.title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(alert.isEnabled ? 0.08 : 0.03))
        )
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
    
    @State private var isHovered = false
    
    private var isComplete: Bool {
        detail?.isEffectivelyComplete ?? milestone.isCompleted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isComplete ? .green : .gray.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Toggle complete")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title)
                        .font(.system(size: 12, weight: .medium))
                        .strikethrough(isComplete, color: .secondary)
                        .foregroundStyle(isComplete ? .secondary : .primary)
                        .lineLimit(1)
                    
                    if let detail, detail.targetsTotalCount > 0, project.hasStarted {
                        Text("\(detail.targetsMetCount)/\(detail.targetsTotalCount) targets met")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    } else if milestone.hasLinkedGoals {
                        Text("\(milestone.linkedGoals.count) linked task\(milestone.linkedGoals.count == 1 ? "" : "s")")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                if !milestoneAlerts.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                        Text("\(milestoneAlerts.count)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.orange)
                }
                
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                
                if let date = milestone.completedAt, isComplete {
                    Text(date, style: .date)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            
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
                Button(action: onAddGoal) {
                    HStack(spacing: 6) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 11))
                        Text("Link daily task")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Button(action: onAddAlert) {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 11))
                        Text("Alert")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isComplete ? Color.green.opacity(0.06) : Color.primary.opacity(0.03))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private func linkedGoalRow(_ link: MilestoneGoalLink) -> some View {
        let goal = dataStore.goals.first { $0.id == link.goalId }
        let count = detail?.goalProgress.first { $0.linkId == link.id }?.count ?? 0
        
        HStack(spacing: 8) {
            if let goal {
                GoalIconView(icon: goal.icon, size: 10, isActive: goal.isActive)
                Text(goal.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("Missing goal")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if project.hasStarted {
                if let target = link.targetCount, target > 0 {
                    Text(formatCount(count) + "/\(target)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(count + 0.0001 >= Double(target) ? .green : .blue)
                } else {
                    Text(formatCount(count))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else if let target = link.targetCount, target > 0 {
                Text("Target \(target)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            
            Button {
                onEditTarget(link)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Set optional target")
            
            Button {
                onRemoveLink(link.id)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.05))
        )
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
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Link Daily Task")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Color.clear.frame(width: 44, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    let available = dataStore.goals.filter { $0.isActive && !alreadyLinked.contains($0.id) }
                    if available.isEmpty {
                        Text("No more daily tasks to link.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(24)
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
                                    GoalIconView(icon: goal.icon, size: 12, isActive: true)
                                    Text(goal.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.03))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
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
        VStack(spacing: 16) {
            Text("Task Target")
                .font(.system(size: 14, weight: .semibold))
            
            Toggle("Set target count", isOn: $hasTarget)
                .toggleStyle(.switch)
                .controlSize(.small)
            
            if hasTarget {
                HStack {
                    Text("Target")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("", value: $targetValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("completions")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            
            Text("Partial days count as 0.5. Leave off to track without a target.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
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
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
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
    
    return ProjectDetailView(project: project)
        .environment(store)
        .frame(width: 480, height: 600)
}
