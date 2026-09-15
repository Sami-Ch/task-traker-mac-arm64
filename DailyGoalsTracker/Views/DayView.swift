import SwiftUI

/// Daily goals view with progress ring and goal list
struct DayView: View {
    @Environment(DataStore.self) private var dataStore
    @Binding var selectedDate: Date
    
    @State private var showingOneOff = false
    
    private var presentation: CalendarPresentation {
        dataStore.calendarPresentation
    }
    
    private var summary: DailySummary {
        dataStore.getDailySummary(for: selectedDate)
    }
    
    private var dayGoals: (tracked: [Goal], skipped: [Goal]) {
        dataStore.goalsForDay(selectedDate)
    }
    
    private var isToday: Bool {
        dataStore.isLogicalToday(selectedDate)
    }
    
    private var isHistory: Bool {
        dataStore.isMembershipFrozen(on: selectedDate)
    }
    
    private var addableGoals: [Goal] {
        dataStore.goalsAvailableToAdd(on: selectedDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PeriodNavigationHeader(
                title: presentation.relativeTitle(for: selectedDate, logicalToday: dataStore.logicalDate()),
                subtitle: isToday && dataStore.settings.calendarDisplay == .gregorian ? nil : presentation.dateSubtitle(for: selectedDate),
                onPrevious: {
                    selectedDate = presentation.shiftedDay(selectedDate, by: -1)
                },
                onNext: {
                    selectedDate = presentation.shiftedDay(selectedDate, by: 1)
                }
            )
            
            Divider().padding(.horizontal)
            
            DayModePicker(date: selectedDate)
            
            NextPrayerBanner()
            
            AppTimeLimitBanner()
            
            Divider().padding(.horizontal)
            
            HStack(spacing: 8) {
                MiniProgressRing(progress: summary.completionPercentage, size: 14)
                Text("\(Int(summary.completionPercentage * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                if summary.isSpecialDay {
                    Image(systemName: summary.dayMode.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(summary.dayMode.color)
                }
                HStack(spacing: 8) {
                    compactStat(count: summary.doneCount, color: .green)
                    compactStat(count: summary.partialCount, color: .orange)
                    compactStat(count: summary.notDoneCount, color: .gray)
                }
                Spacer(minLength: 0)
                if isHistory {
                    Text("History")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .help("This day's list is saved. You can still add or remove tasks; the weekly template will not rewrite it.")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: SummaryStrip.height)
            
            goalRows
            
            Divider().padding(.horizontal)
            
            JournalPreviewCard(date: selectedDate)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showingOneOff) {
            OneOffTaskSheet(date: selectedDate)
                .frame(width: 360, height: 280)
        }
    }
    
    private var goalRows: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if isToday {
                    UsageGoalsSection()
                }
                
                ForEach(dayGoals.tracked) { goal in
                    let entry = dataStore.getEntry(for: goal.id, on: selectedDate)
                    let oneOff = dataStore.isOneOff(goal.id, on: selectedDate)
                    GoalRow(goal: goal, entry: entry, isOneOff: oneOff) {
                        dataStore.cycleStatus(for: goal.id, on: selectedDate)
                    }
                    .contextMenu {
                        Button(oneOff ? "Remove one-off" : "Hide from this day") {
                            dataStore.hideGoal(goal.id, on: selectedDate)
                        }
                    }
                }
                
                Menu {
                    Button("New one-off task…") {
                        showingOneOff = true
                    }
                    if !addableGoals.isEmpty {
                        Divider()
                        ForEach(addableGoals) { goal in
                            Button {
                                dataStore.addGoalOverride(goal.id, on: selectedDate)
                            } label: {
                                Label(goal.title, systemImage: goal.icon)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text("Add for this day")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                
                SkippedGoalsSection(goals: dayGoals.skipped)
            }
            .padding(.top, 4)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.top)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private func compactStat(count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
    }
}

private struct OneOffTaskSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    
    @State private var title = ""
    @State private var icon = "star.fill"
    
    private let icons = [
        "star.fill", "bolt.fill", "flag.fill", "checkmark.circle.fill",
        "cart.fill", "phone.fill", "envelope.fill", "hammer.fill",
        "book.fill", "heart.fill", "leaf.fill", "lightbulb.fill"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("One-off task")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Add") { save() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Only this day — not added to the library.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                TextField("What do you need to do?", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(icons, id: \.self) { name in
                        Button { icon = name } label: {
                            let tint = GoalIconPalette.color(for: name)
                            Image(systemName: name)
                                .font(.system(size: 14))
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(icon == name ? tint.opacity(0.25) : Color.gray.opacity(0.1))
                                )
                                .foregroundStyle(icon == name ? tint : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            
            Spacer()
        }
    }
    
    private func save() {
        dataStore.addOneOffTask(title: title, icon: icon, on: date)
        dismiss()
    }
}

#Preview("Day View") {
    DayView(selectedDate: .constant(Date()))
        .environment(DataStore())
        .environment(PrayerService())
        .environment(AppUsageService())
        .frame(width: 400, height: 600)
}
