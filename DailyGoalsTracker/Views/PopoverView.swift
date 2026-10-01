import SwiftUI

/// Fill for the menu-bar panel. Near-black, matching Cursor’s menu.
enum PanelChrome {
    static let background = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let cornerRadius: CGFloat = 12
    static let width: CGFloat = 400
    static let height: CGFloat = 600
}

/// Main view displayed in the menu bar panel.
struct PopoverView: View {
    @Environment(DataStore.self) private var dataStore
    
    @State private var selectedTab: ViewTab = .day
    @State private var selectedDate = Date()
    
    enum ViewTab: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case projects = "Projects"
        
        var icon: String {
            switch self {
            case .day: return "sun.max"
            case .week: return "calendar.day.timeline.leading"
            case .month: return "calendar"
            case .projects: return "flag.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topBar
            tabPicker
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            tabContent
        }
        .frame(width: PanelChrome.width, height: PanelChrome.height)
        .background(PanelChrome.background)
        .clipShape(RoundedRectangle(cornerRadius: PanelChrome.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PanelChrome.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onReceive(NotificationCenter.default.publisher(for: .resetPopoverToToday)) { _ in
            dataStore.ensureDaySnapshotsCurrent()
            selectedDate = dataStore.logicalDate()
            selectedTab = .day
        }
        .onAppear {
            dataStore.ensureDaySnapshotsCurrent()
            selectedDate = dataStore.logicalDate()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        ZStack {
            leadingLabel
                .frame(maxWidth: .infinity, alignment: .leading)
            
            streakSlot
            
            settingsButton
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }
    
    private var leadingLabel: some View {
        Group {
            if selectedTab == .projects {
                Text("\(dataStore.activeProjects.count) Active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    selectedDate = dataStore.logicalDate()
                } label: {
                    Text("Today")
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(dataStore.isLogicalToday(selectedDate) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.accentColor))
                .disabled(dataStore.isLogicalToday(selectedDate))
            }
        }
        .fixedSize()
    }
    
    private var streakSlot: some View {
        let streak = selectedTab == .projects ? 0 : dataStore.getCurrentStreak()
        return HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(streak)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .opacity(streak > 0 ? 1 : 0)
        .allowsHitTesting(false)
    }
    
    private var settingsButton: some View {
        Button {
            NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Settings (⌘,)")
    }
    
    // MARK: - Tab Picker
    
    private var tabPicker: some View {
        HStack(spacing: 2) {
            ForEach(ViewTab.allCases, id: \.rawValue) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(Color.accentColor)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }
    
    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .day:
                DayView(selectedDate: $selectedDate)
            case .week:
                WeekView(selectedDate: $selectedDate)
            case .month:
                MonthView(selectedDate: $selectedDate) { date in
                    selectedDate = date
                    selectedTab = .day
                }
            case .projects:
                ProjectsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}

#Preview("Popover View") {
    PopoverView()
        .environment(DataStore())
        .environment(PrayerService())
        .environment(AppUsageService())
        .environment(SettingsRouter())
}
