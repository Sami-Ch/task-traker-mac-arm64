import SwiftUI

// MARK: - Settings Pane Enum

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case goals = "Goals"
    case schedule = "Schedule"
    case modes = "Day Modes"
    case prayer = "Prayer"
    case appTime = "App Time"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .goals: return "checklist"
        case .schedule: return "calendar.badge.clock"
        case .modes: return "circle.grid.2x2.fill"
        case .prayer: return "moon.stars.fill"
        case .appTime: return "clock.fill"
        }
    }
    
    var sectionHeader: String? {
        switch self {
        case .general: return nil
        case .goals: return "Tracking"
        case .prayer: return "Integrations"
        default: return nil
        }
    }
}

// MARK: - Settings Window View

struct SettingsWindowView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(PrayerService.self) private var prayer
    @Environment(AppUsageService.self) private var usage
    
    @State private var selectedPane: SettingsPane = .general
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .frame(minWidth: 650, minHeight: 450)
        .frame(idealWidth: 750, idealHeight: 550)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        List(selection: $selectedPane) {
            // General (standalone)
            NavigationLink(value: SettingsPane.general) {
                Label(SettingsPane.general.rawValue, systemImage: SettingsPane.general.icon)
            }
            
            // Tracking section
            Section("Tracking") {
                ForEach([SettingsPane.goals, .schedule, .modes], id: \.self) { pane in
                    NavigationLink(value: pane) {
                        Label(pane.rawValue, systemImage: pane.icon)
                    }
                }
            }
            
            // Integrations section
            Section("Integrations") {
                ForEach([SettingsPane.prayer, .appTime], id: \.self) { pane in
                    NavigationLink(value: pane) {
                        Label(pane.rawValue, systemImage: pane.icon)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
    }
    
    // MARK: - Detail Pane
    
    @ViewBuilder
    private var detailPane: some View {
        switch selectedPane {
        case .general:
            GeneralSettingsPane()
        case .goals:
            GoalsSettingsPane()
        case .schedule:
            ScheduleSettingsPane()
        case .modes:
            ModesSettingsPane()
        case .prayer:
            PrayerSettingsPane()
        case .appTime:
            AppTimeSettingsPane()
        }
    }
}

// MARK: - Preview

#Preview("Settings Window") {
    SettingsWindowView()
        .environment(DataStore())
        .environment(PrayerService())
        .environment(AppUsageService())
}
