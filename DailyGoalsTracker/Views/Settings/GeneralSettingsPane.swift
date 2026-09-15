import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Goals Tracker")
                            .font(.title2.weight(.semibold))
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("Calendar Display") {
                Picker("Calendar System", selection: calendarBinding) {
                    Text("Gregorian").tag(CalendarDisplayMode.gregorian)
                    Text("Islamic (Hijri)").tag(CalendarDisplayMode.hijri)
                    Text("Both").tag(CalendarDisplayMode.dual)
                }
                .pickerStyle(.segmented)
                
                if dataStore.settings.calendarDisplay != .gregorian {
                    Text("Islamic dates use Umm al-Qura calendar. Week starts on Saturday in Hijri mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Appearance") {
                Text("Additional appearance settings coming soon.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Section("Data") {
                LabeledContent("Goals") {
                    Text("\(dataStore.goals.count) total")
                        .foregroundStyle(.secondary)
                }
                
                LabeledContent("Day Modes") {
                    Text("\(dataStore.dayModes.count) modes")
                        .foregroundStyle(.secondary)
                }
                
                LabeledContent("Data Location") {
                    Text("~/Library/Application Support/DailyGoalsTracker")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
    
    private var calendarBinding: Binding<CalendarDisplayMode> {
        Binding(
            get: { dataStore.settings.calendarDisplay },
            set: { newValue in
                dataStore.updateSettings { $0.calendarDisplay = newValue }
            }
        )
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    GeneralSettingsPane()
        .environment(DataStore())
        .frame(width: 500, height: 400)
}
