import SwiftUI

/// Schedule settings pane for the Settings window - day bounds and weekly template.
struct ScheduleSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(PrayerService.self) private var prayer
    
    private var presentation: CalendarPresentation {
        dataStore.calendarPresentation
    }
    
    var body: some View {
        Form {
            Section("Day Boundaries") {
                Toggle(isOn: maghribBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day starts at Maghrib")
                        Text(prayer.isEnabled
                             ? "Islamic day rolls over at sunset"
                             : "Enable Prayer Times to use live Maghrib")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !dataStore.settings.dayStartsAtMaghrib {
                    HStack(spacing: 24) {
                        LabeledContent("Day Starts") {
                            DatePicker(
                                "Starts",
                                selection: startBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                        
                        LabeledContent("Day Ends") {
                            DatePicker(
                                "Ends",
                                selection: endBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                    }
                }
                
                Text(dataStore.settings.dayStartsAtMaghrib
                     ? "The task list freezes at Maghrib and the next day's tasks begin."
                     : "Monday's list freezes at end time; Tuesday's list starts at start time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Weekly Template") {
                if dataStore.goals.isEmpty {
                    Text("Add goals in the Goals settings first to configure the weekly template.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Toggle days to include or skip each goal. Past frozen days stay unchanged.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Header row
                        HStack(spacing: 0) {
                            Text("Goal")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(presentation.weekdayOrder, id: \.rawValue) { weekday in
                                Text(presentation.weekdayName(weekday, style: .letter))
                                    .font(.caption.weight(isJumuah(weekday) ? .bold : .medium))
                                    .foregroundStyle(isJumuah(weekday) ? .green : .secondary)
                                    .frame(width: 32)
                            }
                        }
                        
                        Divider()
                        
                        // Goal rows
                        ForEach(dataStore.goals) { goal in
                            scheduleRow(goal)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Schedule")
    }
    
    private func scheduleRow(_ goal: Goal) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                GoalIconView(icon: goal.icon, size: 12, isActive: goal.isActive)
                Text(goal.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(goal.isActive ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(presentation.weekdayOrder, id: \.rawValue) { weekday in
                let isOn = goal.weekdays.contains(weekday)
                Button {
                    dataStore.toggleWeekday(weekday, for: goal.id)
                } label: {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(isOn ? (isJumuah(weekday) ? .green : .blue) : .gray.opacity(0.3))
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("\(presentation.weekdayName(weekday, style: .full))")
            }
        }
        .opacity(goal.isActive ? 1 : 0.5)
    }
    
    private func isJumuah(_ weekday: WeekdaySet) -> Bool {
        dataStore.settings.calendarDisplay.usesIslamicWeek && weekday == .friday
    }
    
    // MARK: - Bindings
    
    private var maghribBinding: Binding<Bool> {
        Binding(
            get: { dataStore.settings.dayStartsAtMaghrib },
            set: { value in dataStore.updateSettings { $0.dayStartsAtMaghrib = value } }
        )
    }
    
    private var startBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: dataStore.settings.dayStartMinutes) },
            set: { date in
                let minutes = Self.minutes(from: date)
                dataStore.updateSettings { $0.dayStartMinutes = minutes }
            }
        )
    }
    
    private var endBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: dataStore.settings.dayEndMinutes) },
            set: { date in
                let minutes = Self.minutes(from: date)
                dataStore.updateSettings { $0.dayEndMinutes = minutes }
            }
        )
    }
    
    private static func date(fromMinutes minutes: Int) -> Date {
        let clamped = TrackerSettings.clampedMinutes(minutes)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = clamped / 60
        components.minute = clamped % 60
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

#Preview("Schedule Settings") {
    ScheduleSettingsPane()
        .environment(DataStore())
        .environment(PrayerService())
        .frame(width: 550, height: 500)
}
