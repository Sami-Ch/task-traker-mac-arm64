import SwiftUI

// MARK: - Settings Pane Enum

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
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
}

// MARK: - Settings Router

@Observable
final class SettingsRouter {
    var selectedPane: SettingsPane = .general
    var goalIdToEdit: UUID?
    
    func editGoal(_ goalId: UUID) {
        selectedPane = .goals
        goalIdToEdit = goalId
    }
    
    func clearGoalEdit() {
        goalIdToEdit = nil
    }
}

// MARK: - Settings Window View

struct SettingsWindowView: View {
    @Environment(SettingsRouter.self) private var settingsRouter
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    private static let windowSize = CGSize(width: 780, height: 540)
    private static let sidebarWidth: CGFloat = 200
    
    var body: some View {
        @Bindable var router = settingsRouter
        
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $router.selectedPane) {
                Section {
                    settingsLink(.general)
                }
                
                Section("Tracking") {
                    settingsLink(.goals)
                    settingsLink(.schedule)
                    settingsLink(.modes)
                }
                
                Section("Integrations") {
                    settingsLink(.prayer)
                    settingsLink(.appTime)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(
                min: Self.sidebarWidth,
                ideal: Self.sidebarWidth,
                max: 240
            )
        } detail: {
            detailPane(for: router.selectedPane)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: Self.windowSize.width,
            idealWidth: Self.windowSize.width,
            minHeight: Self.windowSize.height,
            idealHeight: Self.windowSize.height
        )
        .onAppear {
            columnVisibility = .all
        }
    }
    
    private func settingsLink(_ pane: SettingsPane) -> some View {
        NavigationLink(value: pane) {
            Label(pane.rawValue, systemImage: pane.icon)
        }
        .tag(pane)
    }
    
    @ViewBuilder
    private func detailPane(for selectedPane: SettingsPane) -> some View {
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
        .environment(SettingsRouter())
}
