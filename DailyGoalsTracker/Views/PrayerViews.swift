import SwiftUI

/// Settings content for location-based prayer times and notifications.
struct PrayerSettingsPanel: View {
    @Environment(PrayerService.self) private var prayer
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                enableRow
                if prayer.isEnabled {
                    locationRow
                    methodPickers
                    notifyPicker
                    if prayer.isLoading {
                        ProgressView("Calculating times…")
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    }
                    if let message = prayer.statusMessage {
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }
                    timingsList
                } else {
                    Text("Turn on to use your Mac’s location, calculate today’s prayer times, and get notified before each prayer.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }
    
    private var enableRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Prayer times")
                    .font(.system(size: 13, weight: .medium))
                Text("Based on current location")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { prayer.isEnabled },
                set: { prayer.isEnabled = $0 }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }
    
    private var locationRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.system(size: 11))
                .foregroundStyle(.blue)
            Text(prayer.locationLabel)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button {
                Task { await prayer.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .disabled(prayer.isLoading)
            .help("Refresh location & times")
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.08)))
    }
    
    private var methodPickers: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calculation method")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { prayer.method },
                    set: { prayer.method = $0 }
                )) {
                    ForEach(PrayerCalculationMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                .labelsHidden()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Asr school")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { prayer.school },
                    set: { prayer.school = $0 }
                )) {
                    ForEach(AsrJuristicSchool.allCases) { school in
                        Text(school.title).tag(school)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var notifyPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notify me")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: { prayer.notifyMinutesBefore },
                set: { prayer.notifyMinutesBefore = $0 }
            )) {
                Text("At prayer time").tag(0)
                Text("5 min before").tag(5)
                Text("10 min before").tag(10)
                Text("15 min before").tag(15)
            }
            .labelsHidden()
        }
    }
    
    @ViewBuilder
    private var timingsList: some View {
        if let schedule = prayer.schedule {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                ForEach(schedule.timings) { timing in
                    let isNext = prayer.nextPrayer?.id == timing.id
                    HStack(spacing: 10) {
                        Image(systemName: timing.name.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(isNext ? .blue : .secondary)
                            .frame(width: 16)
                        Text(timing.name.rawValue)
                            .font(.system(size: 13, weight: isNext ? .semibold : .medium))
                        Spacer()
                        Text(Self.timeFormatter.string(from: timing.date))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(isNext ? .blue : .primary)
                        if isNext {
                            Text("NEXT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isNext ? Color.blue.opacity(0.1) : Color.gray.opacity(0.06))
                    )
                }
            }
        }
    }
}

/// Compact next-prayer strip for Day view.
struct NextPrayerBanner: View {
    @Environment(PrayerService.self) private var prayer
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        if prayer.isEnabled, let next = prayer.nextPrayer {
            HStack(spacing: 8) {
                Image(systemName: next.name.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.indigo)
                Text("Next: \(next.name.rawValue)")
                    .font(.system(size: 11, weight: .semibold))
                Text(Self.timeFormatter.string(from: next.date))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if prayer.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.indigo.opacity(0.08))
        }
    }
}
