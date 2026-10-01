import SwiftUI

// MARK: - Settings Pane Enum

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general = "General"
    case goals = "Tasks"
    case projects = "Projects"
    case schedule = "Schedule"
    case modes = "Day Modes"
    case prayer = "Prayer"
    case appTime = "App Time"
    case reports = "Reports"
    case suggestAI = "Suggest AI"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .goals: return "checklist"
        case .projects: return "flag.fill"
        case .schedule: return "calendar.badge.clock"
        case .modes: return "circle.grid.2x2.fill"
        case .prayer: return "moon.stars.fill"
        case .appTime: return "clock.fill"
        case .reports: return "text.page"
        case .suggestAI: return "sparkles"
        }
    }
}

// MARK: - Settings Router

@Observable
final class SettingsRouter {
    var selectedPane: SettingsPane = .general
    var goalIdToEdit: UUID?
    var reportIdToOpen: String?
    var projectIdToOpen: UUID?
    
    func editGoal(_ goalId: UUID) {
        selectedPane = .goals
        goalIdToEdit = goalId
    }
    
    func clearGoalEdit() {
        goalIdToEdit = nil
    }
    
    func showReport(_ id: String) {
        selectedPane = .reports
        reportIdToOpen = id
    }
    
    func clearReportOpen() {
        reportIdToOpen = nil
    }
    
    func showProjects() {
        selectedPane = .projects
        projectIdToOpen = nil
    }
    
    func showProject(_ id: UUID) {
        selectedPane = .projects
        projectIdToOpen = id
    }
    
    func clearProjectOpen() {
        projectIdToOpen = nil
    }
}

// MARK: - Settings Window View

struct SettingsWindowView: View {
    @Environment(SettingsRouter.self) private var settingsRouter
    
    private static let windowSize = CGSize(width: 780, height: 540)
    private static let sidebarWidth: CGFloat = 200
    
    var body: some View {
        @Bindable var router = settingsRouter
        
        HStack(spacing: 0) {
            List(selection: $router.selectedPane) {
                Section {
                    settingsLink(.general)
                }
                
                Section("Apple Intelligence") {
                    settingsLink(.suggestAI)
                    settingsLink(.reports)
                }
                
                Section("Tracking") {
                    settingsLink(.goals)
                    settingsLink(.projects)
                    settingsLink(.schedule)
                    settingsLink(.modes)
                }
                
                Section("Integrations") {
                    settingsLink(.prayer)
                    settingsLink(.appTime)
                }
            }
            .listStyle(.sidebar)
            .frame(width: Self.sidebarWidth)
            
            detailPane(for: router.selectedPane)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: Self.windowSize.width,
            idealWidth: Self.windowSize.width,
            minHeight: Self.windowSize.height,
            idealHeight: Self.windowSize.height
        )
    }
    
    private func settingsLink(_ pane: SettingsPane) -> some View {
        Label(pane.rawValue, systemImage: pane.icon)
            .tag(pane)
    }
    
    @ViewBuilder
    private func detailPane(for selectedPane: SettingsPane) -> some View {
        switch selectedPane {
        case .general:
            GeneralSettingsPane()
        case .goals:
            GoalsSettingsPane()
        case .projects:
            ProjectsSettingsPane()
        case .schedule:
            ScheduleSettingsPane()
        case .modes:
            ModesSettingsPane()
        case .prayer:
            PrayerSettingsPane()
        case .appTime:
            AppTimeSettingsPane()
        case .reports:
            ReportsSettingsPane()
        case .suggestAI:
            SuggestAISettingsPane()
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
