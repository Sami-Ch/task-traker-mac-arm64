import SwiftUI

/// Main view displayed in the menu bar popover
struct PopoverView: View {
    @Environment(DataStore.self) private var dataStore
    
    @State private var selectedTab: ViewTab = .day
    @State private var selectedDate = Date()
    @State private var showingSettings = false
    @State private var showingAddGoal = false
    @State private var editingGoal: Goal?
    
    enum ViewTab: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case plan = "Plan"
        
        var icon: String {
            switch self {
            case .day: return "sun.max"
            case .week: return "calendar.day.timeline.leading"
            case .month: return "calendar"
            case .plan: return "flag.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showingSettings {
                SettingsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                mainContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 340, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingAddGoal) {
            GoalEditorSheet(goal: nil)
                .frame(width: 340, height: 420)
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditorSheet(goal: goal)
                .frame(width: 340, height: 420)
        }
        .environment(\.closeSettings, CloseSettingsAction {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingSettings = false
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: .resetPopoverToToday)) { _ in
            selectedDate = Date()
            selectedTab = .day
            showingSettings = false
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top bar with settings
            topBar
            
            // Tab picker
            tabPicker
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Content based on selected tab
            tabContent
        }
    }
    
    // MARK: - Top Bar
    /// Three independent layers so the centered streak badge can never push the
    /// leading label or trailing gear around when it appears or disappears.
    private var topBar: some View {
        ZStack {
            leadingLabel
                .frame(maxWidth: .infinity, alignment: .leading)
            
            streakSlot
            
            settingsButton
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
    }
    
    private var leadingLabel: some View {
        Group {
            if selectedTab == .plan {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text("Big Picture")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.purple)
            } else {
                Button {
                    selectedDate = Date()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11))
                        Text("Today")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.blue)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(Calendar.current.isDateInToday(selectedDate) ? 0.3 : 1)
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }
        }
        .fixedSize()
    }
    
    /// Constant-size slot: the container always exists, only its contents fade in.
    private var streakSlot: some View {
        let streak = selectedTab == .plan ? 0 : dataStore.getCurrentStreak()
        
        return Color.clear
            .frame(width: 60, height: 24)
            .overlay {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("\(streak)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
                .fixedSize()
                .opacity(streak > 0 ? 1 : 0)
            }
            .allowsHitTesting(false)
    }
    
    private var settingsButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingSettings = true
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                            .font(.system(size: 10))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(tab == .plan ? Color.purple : Color.blue)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.15))
        )
    }
    
    // MARK: - Tab Content
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
            case .plan:
                PlanningView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}

// MARK: - Settings close action (separate from sheet dismiss)
private struct CloseSettingsActionKey: EnvironmentKey {
    static let defaultValue: CloseSettingsAction = CloseSettingsAction {}
}

extension EnvironmentValues {
    var closeSettings: CloseSettingsAction {
        get { self[CloseSettingsActionKey.self] }
        set { self[CloseSettingsActionKey.self] = newValue }
    }
}

struct CloseSettingsAction {
    let action: () -> Void
    
    init(_ action: @escaping () -> Void = {}) {
        self.action = action
    }
    
    func callAsFunction() {
        action()
    }
}

// MARK: - Preview
#Preview("Popover View") {
    PopoverView()
        .environment(DataStore())
}
