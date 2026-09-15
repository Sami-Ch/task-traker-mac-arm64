import SwiftUI

/// Calendar mode, day bounds, and weekly weekday template.
struct ScheduleSettingsPanel: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(PrayerService.self) private var prayer
    
    private var presentation: CalendarPresentation {
        dataStore.calendarPresentation
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                calendarSection
                dayClockSection
                templateSection
            }
            .padding(16)
        }
    }
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            Picker("Calendar", selection: calendarBinding) {
                ForEach(CalendarDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            Text("Hijri uses Umm al-Qura. History is still stored on the civil date.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
    
    private var dayClockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Day bounds")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            Toggle(isOn: maghribBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day starts at Maghrib")
                        .font(.system(size: 12, weight: .medium))
                    Text(prayer.isEnabled
                         ? "Islamic day rolls over at sunset"
                         : "Turn on Prayer times to use live Maghrib; otherwise the start time below is used")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Starts")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    DatePicker(
                        "Starts",
                        selection: startBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .disabled(dataStore.settings.dayStartsAtMaghrib)
                    .opacity(dataStore.settings.dayStartsAtMaghrib ? 0.45 : 1)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ends")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    DatePicker(
                        "Ends",
                        selection: endBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .disabled(dataStore.settings.dayStartsAtMaghrib)
                    .opacity(dataStore.settings.dayStartsAtMaghrib ? 0.45 : 1)
                }
            }
            
            Text(dataStore.settings.dayStartsAtMaghrib
                 ? "The list freezes at Maghrib and the next day’s tasks begin."
                 : "Monday’s list freezes at end time; Tuesday’s list starts at start time.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
    
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly template")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            Text("Tap a day to include or skip that goal. Frozen past days stay as they were.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            
            if dataStore.goals.isEmpty {
                Text("Add goals in the Goals panel first.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 0) {
                    Text("Goal")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(presentation.weekdayOrder, id: \.rawValue) { weekday in
                        Text(presentation.weekdayName(weekday, style: .letter))
                            .font(.system(size: 9, weight: presentation.isJumuahLetter(weekday) ? .bold : .medium))
                            .foregroundStyle(presentation.isJumuahLetter(weekday) ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                            .frame(width: 28)
                            .help(presentation.islamicArabicName(weekday))
                    }
                }
                
                VStack(spacing: 4) {
                    ForEach(dataStore.goals) { goal in
                        scheduleRow(goal)
                    }
                }
            }
        }
    }
    
    private func scheduleRow(_ goal: Goal) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                GoalIconView(icon: goal.icon, size: 10, isActive: goal.isActive)
                Text(goal.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(goal.isActive ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(presentation.weekdayOrder, id: \.rawValue) { weekday in
                let on = goal.weekdays.contains(weekday)
                Button {
                    dataStore.toggleWeekday(weekday, for: goal.id)
                } label: {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(on ? (presentation.isJumuahLetter(weekday) ? .green : .blue) : .gray.opacity(0.35))
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("\(presentation.weekdayName(weekday, style: .full)) (\(presentation.islamicArabicName(weekday)))")
            }
        }
        .opacity(goal.isActive ? 1 : 0.55)
    }
    
    private var calendarBinding: Binding<CalendarDisplayMode> {
        Binding(
            get: { dataStore.settings.calendarDisplay },
            set: { value in dataStore.updateSettings { $0.calendarDisplay = value } }
        )
    }
    
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

struct WeekdayChipsView: View {
    @Binding var weekdays: WeekdaySet
    var presentation: CalendarPresentation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(presentation.weekdayOrder, id: \.rawValue) { weekday in
                let on = weekdays.contains(weekday)
                Button {
                    toggle(weekday)
                } label: {
                    Text(presentation.weekdayName(weekday, style: .letter))
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(on ? .white : .secondary)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(on ? (presentation.isJumuahLetter(weekday) ? Color.green : Color.blue) : Color.gray.opacity(0.12))
                        }
                }
                .buttonStyle(.plain)
                .help("\(presentation.weekdayName(weekday, style: .full)) (\(presentation.islamicArabicName(weekday)))")
            }
        }
    }
    
    private func toggle(_ weekday: WeekdaySet) {
        if weekdays.contains(weekday) {
            var next = weekdays
            next.remove(weekday)
            if !next.isEmpty {
                weekdays = next
            }
        } else {
            weekdays.insert(weekday)
        }
    }
}

private extension CalendarPresentation {
    func isJumuahLetter(_ weekday: WeekdaySet) -> Bool {
        mode.usesIslamicWeek && weekday == .friday
    }
}

#Preview("Schedule") {
    ScheduleSettingsPanel()
        .environment(DataStore())
        .environment(PrayerService())
        .frame(width: 400, height: 600)
}
