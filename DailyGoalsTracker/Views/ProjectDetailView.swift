import SwiftUI

/// Detail view for a single project
struct ProjectDetailView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    
    @State private var showingEditor = false
    @State private var newMilestoneTitle = ""
    @State private var showPlanEditor = false
    
    private var currentProject: Project {
        dataStore.project(for: project.id) ?? project
    }
    
    private var progress: ProjectProgress {
        dataStore.projectProgress(for: currentProject)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Progress section
                    progressSection
                    
                    // Description
                    if !currentProject.description.isEmpty {
                        descriptionSection
                    }
                    
                    // Linked tasks
                    if currentProject.hasLinkedGoals {
                        linkedTasksSection
                    }
                    
                    // Milestones
                    milestonesSection
                    
                    // Plan & Notes
                    planSection
                }
                .padding(16)
            }
            
            Divider()
            
            // Actions footer
            actionsFooter
        }
        .sheet(isPresented: $showingEditor) {
            ProjectEditorSheet(project: currentProject)
                .frame(width: 480, height: 600)
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
                    Text(currentProject.status.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(currentProject.status.color)
                    
                    Text("·")
                        .foregroundStyle(.tertiary)
                    
                    if let deadline = currentProject.targetDate {
                        Text("Due \(deadline, style: .date)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else if Calendar.current.startOfDay(for: currentProject.startDate) > Calendar.current.startOfDay(for: Date()) {
                        Text("Starts \(currentProject.startDate, style: .date)")
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
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 10)
                    
                    Capsule()
                        .fill(currentProject.isCompleted ? Color.green : currentProject.color)
                        .frame(width: geo.size.width * progress.overallProgress, height: 10)
                }
            }
            .frame(height: 10)
            
            // Stats row
            HStack(spacing: 16) {
                if currentProject.hasTargetCount {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Tasks")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.system(size: 10))
                            Text("\(progress.linkedCompletions)/\(currentProject.targetCount ?? 0)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.blue)
                    }
                } else if currentProject.hasLinkedGoals {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Completions")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                            Text("\(progress.linkedCompletions)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.blue)
                    }
                }
                
                if currentProject.hasMilestones {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Milestones")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 4) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 10))
                            Text("\(progress.completedMilestones)/\(progress.totalMilestones)")
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
                    Text("\(progress.overallProgressPercent)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(currentProject.isCompleted ? .green : currentProject.color)
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
    
    // MARK: - Linked Tasks Section
    
    private var linkedTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked Daily Tasks")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            ForEach(currentProject.linkedGoalIds, id: \.self) { goalId in
                if let goal = dataStore.goals.first(where: { $0.id == goalId }) {
                    let count = dataStore.completionsForGoal(goalId, in: currentProject.dateRange)
                    HStack(spacing: 10) {
                        GoalIconView(icon: goal.icon, size: 12, isActive: goal.isActive)
                        Text(goal.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(count) completions")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.06))
                    )
                }
            }
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
                if currentProject.hasMilestones {
                    Text("\(progress.completedMilestones)/\(progress.totalMilestones) complete")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Existing milestones
            ForEach(currentProject.milestones.sorted { $0.order < $1.order }) { milestone in
                MilestoneRow(
                    milestone: milestone,
                    onToggle: {
                        dataStore.toggleProjectMilestone(projectId: currentProject.id, milestoneId: milestone.id)
                    },
                    onDelete: {
                        dataStore.removeMilestone(from: currentProject.id, milestoneId: milestone.id)
                    }
                )
            }
            
            // Add milestone field
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.green.opacity(0.6))
                
                TextField("Add milestone...", text: $newMilestoneTitle)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addMilestone()
                    }
                
                if !newMilestoneTitle.isEmpty {
                    Button {
                        addMilestone()
                    } label: {
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
            } else {
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

// MARK: - Milestone Row

struct MilestoneRow: View {
    let milestone: Milestone
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(milestone.isCompleted ? .green : .gray.opacity(0.4))
            }
            .buttonStyle(.plain)
            
            Text(milestone.title)
                .font(.system(size: 12, weight: .medium))
                .strikethrough(milestone.isCompleted, color: .secondary)
                .foregroundStyle(milestone.isCompleted ? .secondary : .primary)
                .lineLimit(1)
            
            Spacer()
            
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
            
            if let date = milestone.completedAt {
                Text(date, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(milestone.isCompleted ? Color.green.opacity(0.06) : Color.primary.opacity(0.03))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
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
        targetCount: 100,
        milestones: [
            Milestone(title: "Complete A1 level", isCompleted: true, completedAt: Date(), order: 0),
            Milestone(title: "30-day streak", isCompleted: true, completedAt: Date(), order: 1),
            Milestone(title: "Watch first movie in Spanish", order: 2),
            Milestone(title: "Have 10-min conversation", order: 3)
        ],
        colorName: "purple",
        icon: "globe"
    )
    store.addProject(project)
    
    return ProjectDetailView(project: project)
        .environment(store)
        .frame(width: 480, height: 600)
}
