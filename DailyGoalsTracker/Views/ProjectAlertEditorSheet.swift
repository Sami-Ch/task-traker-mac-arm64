import SwiftUI

/// Create or edit a project / milestone alert.
struct ProjectAlertEditorSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let existing: ProjectAlert?
    /// Prefill when adding from a milestone card.
    var initialMilestoneId: UUID? = nil
    
    @State private var title = ""
    @State private var isEnabled = true
    @State private var milestoneId: UUID? = nil
    @State private var scheduleKind: ScheduleKind = .daily
    @State private var hourlyMinute = 0
    @State private var dailyTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var specificDates: [Date] = [Date()]
    @State private var specificTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var deadlineOffset: ProjectAlertDeadlineOffset = .oneDay
    @State private var customOffsetHours = 24
    @State private var untilDeadlineTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var startOffset: ProjectAlertDeadlineOffset = .oneDay
    @State private var customStartOffsetHours = 24
    @State private var onStartTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var sound: ProjectAlertSound = .default
    @State private var newDateToAdd = Date()
    
    private var isEditing: Bool { existing != nil }
    
    enum ScheduleKind: String, CaseIterable, Identifiable {
        case hourly
        case daily
        case specificDates
        case beforeDeadline
        case dailyUntilDeadline
        case beforeStart
        case onStartDay
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .hourly: return "Hourly"
            case .daily: return "Daily"
            case .specificDates: return "Specific dates"
            case .beforeDeadline: return "Before deadline"
            case .dailyUntilDeadline: return "Daily until deadline"
            case .beforeStart: return "Before start"
            case .onStartDay: return "On start day"
            }
        }
    }
    
    private var currentProject: Project {
        dataStore.project(for: project.id) ?? project
    }
    
    private var needsDeadline: Bool {
        scheduleKind == .beforeDeadline || scheduleKind == .dailyUntilDeadline
    }
    
    private var canSave: Bool {
        if needsDeadline && currentProject.targetDate == nil { return false }
        if scheduleKind == .specificDates && specificDates.isEmpty { return false }
        if scheduleKind == .beforeStart || scheduleKind == .onStartDay {
            // Always have startDate; still valid after start if fire time is future
            return true
        }
        return true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleSection
                    scopeSection
                    scheduleSection
                    soundSection
                    Toggle("Enabled", isOn: $isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .padding(16)
            }
        }
        .frame(width: 440, height: 520)
        .onAppear(perform: load)
    }
    
    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Text(isEditing ? "Edit Alert" : "New Alert")
                .font(.headline)
            Spacer()
            Button("Save") { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Title (optional)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Defaults to project or milestone name", text: $title)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Applies to")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            
            Picker("", selection: Binding(
                get: { milestoneId.map { "m:\($0.uuidString)" } ?? "project" },
                set: { value in
                    if value == "project" {
                        milestoneId = nil
                    } else if value.hasPrefix("m:"),
                              let id = UUID(uuidString: String(value.dropFirst(2))) {
                        milestoneId = id
                    }
                }
            )) {
                Text("Entire project").tag("project")
                ForEach(currentProject.milestones.sorted { $0.order < $1.order }) { milestone in
                    Text(milestone.title).tag("m:\(milestone.id.uuidString)")
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            
            Picker("Schedule", selection: $scheduleKind) {
                ForEach(ScheduleKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            
            switch scheduleKind {
            case .hourly:
                HStack {
                    Text("At minute")
                        .font(.system(size: 12))
                    Stepper(value: $hourlyMinute, in: 0...59) {
                        Text(String(format: ":%02d", hourlyMinute))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                }
            case .daily:
                DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
            case .specificDates:
                DatePicker("Time of day", selection: $specificTime, displayedComponents: .hourAndMinute)
                ForEach(Array(specificDates.enumerated()), id: \.offset) { index, date in
                    HStack {
                        Text(date, style: .date)
                            .font(.system(size: 12))
                        Spacer()
                        Button {
                            specificDates.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    DatePicker("", selection: $newDateToAdd, displayedComponents: .date)
                        .labelsHidden()
                    Button("Add date") {
                        let day = GoalEntry.startOfCivilDay(for: newDateToAdd)
                        if !specificDates.contains(where: {
                            Calendar.current.isDate($0, inSameDayAs: day)
                        }) {
                            specificDates.append(day)
                            specificDates.sort()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            case .beforeDeadline:
                if currentProject.targetDate == nil {
                    deadlineMissingHint
                } else {
                    Picker("Offset", selection: $deadlineOffset) {
                        ForEach(ProjectAlertDeadlineOffset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    if deadlineOffset == .custom {
                        HStack {
                            Text("Hours before")
                                .font(.system(size: 12))
                            Stepper(value: $customOffsetHours, in: 1...24 * 30) {
                                Text("\(customOffsetHours)h")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                        }
                    }
                    if let target = currentProject.targetDate {
                        Text("Deadline: \(target.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            case .dailyUntilDeadline:
                if currentProject.targetDate == nil {
                    deadlineMissingHint
                } else {
                    DatePicker("Time each day", selection: $untilDeadlineTime, displayedComponents: .hourAndMinute)
                    if let target = currentProject.targetDate {
                        Text("Until \(target.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            case .beforeStart:
                Picker("Offset", selection: $startOffset) {
                    ForEach(ProjectAlertDeadlineOffset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                if startOffset == .custom {
                    HStack {
                        Text("Hours before")
                            .font(.system(size: 12))
                        Stepper(value: $customStartOffsetHours, in: 1...24 * 30) {
                            Text("\(customStartOffsetHours)h")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                    }
                }
                Text("Starts: \(currentProject.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            case .onStartDay:
                DatePicker("Time on start day", selection: $onStartTime, displayedComponents: .hourAndMinute)
                Text("Starts: \(currentProject.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    private var deadlineMissingHint: some View {
        Text("Set a target date on this project to use deadline-based alerts.")
            .font(.system(size: 11))
            .foregroundStyle(.orange)
    }
    
    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sound")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Picker("", selection: $sound) {
                ForEach(ProjectAlertSound.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }
    
    private func load() {
        if let existing {
            title = existing.title
            isEnabled = existing.isEnabled
            milestoneId = existing.milestoneId
            sound = existing.sound
            switch existing.schedule {
            case .hourly(let minute):
                scheduleKind = .hourly
                hourlyMinute = minute
            case .daily(let hour, let minute):
                scheduleKind = .daily
                dailyTime = timeDate(hour: hour, minute: minute)
            case .specificDates(let dates, let hour, let minute):
                scheduleKind = .specificDates
                specificDates = dates
                specificTime = timeDate(hour: hour, minute: minute)
            case .beforeDeadline(let offset):
                scheduleKind = .beforeDeadline
                deadlineOffset = ProjectAlertDeadlineOffset.matching(offset)
                if deadlineOffset == .custom {
                    customOffsetHours = max(1, Int(offset / 3600))
                }
            case .dailyUntilDeadline(let hour, let minute):
                scheduleKind = .dailyUntilDeadline
                untilDeadlineTime = timeDate(hour: hour, minute: minute)
            case .beforeStart(let offset):
                scheduleKind = .beforeStart
                startOffset = ProjectAlertDeadlineOffset.matching(offset)
                if startOffset == .custom {
                    customStartOffsetHours = max(1, Int(offset / 3600))
                }
            case .onStartDay(let hour, let minute):
                scheduleKind = .onStartDay
                onStartTime = timeDate(hour: hour, minute: minute)
            }
        } else {
            milestoneId = initialMilestoneId
            if currentProject.isUpcoming {
                scheduleKind = .onStartDay
            }
        }
    }
    
    private func timeDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }
    
    private func hourMinute(from date: Date) -> (Int, Int) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0, comps.minute ?? 0)
    }
    
    private func buildSchedule() -> ProjectAlertSchedule? {
        switch scheduleKind {
        case .hourly:
            return .hourly(minute: hourlyMinute)
        case .daily:
            let (h, m) = hourMinute(from: dailyTime)
            return .daily(hour: h, minute: m)
        case .specificDates:
            guard !specificDates.isEmpty else { return nil }
            let (h, m) = hourMinute(from: specificTime)
            return .specificDates(dates: specificDates.map { GoalEntry.startOfCivilDay(for: $0) }, hour: h, minute: m)
        case .beforeDeadline:
            guard currentProject.targetDate != nil else { return nil }
            let seconds: TimeInterval
            if let preset = deadlineOffset.seconds {
                seconds = preset
            } else {
                seconds = TimeInterval(customOffsetHours * 3600)
            }
            return .beforeDeadline(offsetSeconds: seconds)
        case .dailyUntilDeadline:
            guard currentProject.targetDate != nil else { return nil }
            let (h, m) = hourMinute(from: untilDeadlineTime)
            return .dailyUntilDeadline(hour: h, minute: m)
        case .beforeStart:
            let seconds: TimeInterval
            if let preset = startOffset.seconds {
                seconds = preset
            } else {
                seconds = TimeInterval(customStartOffsetHours * 3600)
            }
            return .beforeStart(offsetSeconds: seconds)
        case .onStartDay:
            let (h, m) = hourMinute(from: onStartTime)
            return .onStartDay(hour: h, minute: m)
        }
    }
    
    private func save() {
        guard let schedule = buildSchedule() else { return }
        let alert = ProjectAlert(
            id: existing?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            isEnabled: isEnabled,
            schedule: schedule,
            soundName: sound.rawValue,
            snoozeMinutesDefault: existing?.snoozeMinutesDefault ?? 15,
            milestoneId: milestoneId
        )
        if isEditing {
            dataStore.updateAlert(projectId: currentProject.id, alert: alert)
        } else {
            dataStore.addAlert(to: currentProject.id, alert: alert)
        }
        dismiss()
    }
}
