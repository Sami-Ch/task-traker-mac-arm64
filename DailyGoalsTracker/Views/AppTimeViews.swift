import AppKit
import SwiftUI

/// Settings: pick Mac apps and websites, each with a daily goal and/or cap.
struct AppTimeSettingsPanel: View {
    @Environment(AppUsageService.self) private var usage
    @Binding var showingAddApp: Bool
    @Binding var showingAddWebsite: Bool
    
    private var isEmpty: Bool {
        usage.sortedLimits.isEmpty && usage.sortedWebsiteLimits.isEmpty
    }
    
    var body: some View {
        Group {
            if isEmpty {
                emptyState
            } else {
                limitsList
            }
        }
        .sheet(isPresented: $showingAddApp) {
            AddAppLimitSheet()
                .frame(width: 400, height: 480)
        }
        .sheet(isPresented: $showingAddWebsite) {
            AddWebsiteLimitSheet()
                .frame(width: 400, height: 480)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("No usage rules yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Add an app or website, then set a daily goal (at least 20 minutes, or open once) and/or a cap.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 8) {
                Button("Add an app") { showingAddApp = true }
                Button("Add a website") { showingAddWebsite = true }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var limitsList: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { usage.isEnabled },
                    set: { usage.isEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watch app & website time")
                            .font(.system(size: 13, weight: .medium))
                        Text("Caps stay green on Today until you go over. After that, a reminder every 2 minutes — or Do Not Disturb for 15.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                .toggleStyle(.switch)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                
                DoNotDisturbRow()
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))
            }
            
            Section("Apps") {
                if usage.sortedLimits.isEmpty {
                    Button("Add an app") { showingAddApp = true }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                } else {
                    ForEach(usage.sortedLimits) { limit in
                        AppTimeLimitRow(limit: limit)
                    }
                }
            }
            
            Section("Websites") {
                if !usage.isEnabled {
                    Text("Tracking is paused. Turn on “Watch app & website time” and the switch next to the site.")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                if usage.needsBrowserPermission {
                    Text("Allow this app to read the current tab in System Settings → Privacy & Security → Automation, then keep browsing in that browser.")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                if usage.sortedWebsiteLimits.isEmpty {
                    Button("Add a website") { showingAddWebsite = true }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                } else {
                    ForEach(usage.sortedWebsiteLimits) { limit in
                        WebsiteTimeLimitRow(limit: limit)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct DoNotDisturbRow: View {
    @Environment(AppUsageService.self) private var usage
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: usage.isQuiet ? "moon.fill" : "moon")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(usage.isQuiet ? .indigo : .secondary)
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Do Not Disturb")
                    .font(.system(size: 13, weight: .medium))
                if let remaining = usage.quietRemainingSeconds {
                    Text("Quiet for \(AppTimeFormatting.duration(seconds: remaining))")
                        .font(.system(size: 11))
                        .foregroundStyle(.indigo)
                } else {
                    Text("Snooze cap reminders for \(AppUsageService.snoozeMinutes) min")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer(minLength: 0)
            
            if usage.isQuiet {
                Button("End") {
                    usage.endSnooze()
                }
                .controlSize(.small)
            } else {
                Button("\(AppUsageService.snoozeMinutes) min") {
                    usage.snoozeReminders()
                }
                .controlSize(.small)
            }
        }
    }
}

private struct AppTimeLimitRow: View {
    @Environment(AppUsageService.self) private var usage
    let limit: AppTimeLimit
    
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    
    private var status: UsageProgress {
        usage.status(for: limit)
    }
    
    var body: some View {
        TimeLimitRowChrome(
            icon: { AppIconView(path: limit.appPath, size: 22) },
            title: limit.displayName,
            isLive: usage.activeBundleId == limit.bundleIdentifier,
            progress: status,
            isEnabled: limit.isEnabled,
            floor: limit.floorChoice,
            cap: limit.capChoice,
            onToggle: { usage.setLimitEnabled($0, for: limit.bundleIdentifier) },
            onFloor: { usage.setFloor($0, for: limit.bundleIdentifier) },
            onCap: { usage.setCap($0, for: limit.bundleIdentifier) },
            onDelete: { showDeleteConfirm = true },
            isHovered: $isHovered
        )
        .alert("Remove \(limit.displayName)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                usage.removeLimit(limit.bundleIdentifier)
            }
        } message: {
            Text("Today's time for this app will stop being tracked.")
        }
    }
}

private struct WebsiteTimeLimitRow: View {
    @Environment(AppUsageService.self) private var usage
    let limit: WebsiteTimeLimit
    
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    
    private var status: UsageProgress {
        usage.status(for: limit)
    }
    
    var body: some View {
        TimeLimitRowChrome(
            icon: {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue.opacity(0.12)))
            },
            title: limit.domain,
            isLive: usage.activeWebsiteDomain == limit.domain,
            progress: status,
            isEnabled: limit.isEnabled,
            floor: limit.floorChoice,
            cap: limit.capChoice,
            onToggle: { usage.setWebsiteEnabled($0, for: limit.domain) },
            onFloor: { usage.setWebsiteFloor($0, for: limit.domain) },
            onCap: { usage.setWebsiteCap($0, for: limit.domain) },
            onDelete: { showDeleteConfirm = true },
            isHovered: $isHovered
        )
        .alert("Remove \(limit.domain)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                usage.removeWebsiteLimit(limit.domain)
            }
        } message: {
            Text("Today's time on this site will stop being tracked.")
        }
    }
}

private struct TimeLimitRowChrome<Icon: View>: View {
    @ViewBuilder var icon: () -> Icon
    let title: String
    let isLive: Bool
    let progress: UsageProgress
    let isEnabled: Bool
    let floor: UsageFloorChoice
    let cap: UsageCapChoice
    let onToggle: (Bool) -> Void
    let onFloor: (UsageFloorChoice) -> Void
    let onCap: (UsageCapChoice) -> Void
    let onDelete: () -> Void
    @Binding var isHovered: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                icon()
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        if isLive {
                            Text("NOW")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.orange))
                        }
                    }
                    Text(progress.summaryText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(progress.isOverMax ? .red : ((progress.hasCap || progress.isMinMet) ? .green : .secondary))
                }
                
                Spacer(minLength: 0)
                
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                }
            }
            
            ProgressView(value: progress.barProgress)
                .tint(progress.isOverMax ? .red : ((progress.hasCap || progress.isMinMet) ? .green : (progress.barProgress > 0.8 ? .orange : .blue)))
            
            HStack {
                Text("Goal")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Picker("", selection: Binding(get: { floor }, set: onFloor)) {
                    Text("None").tag(UsageFloorChoice.none)
                    Text("Once").tag(UsageFloorChoice.once)
                    ForEach(floorMinuteTags, id: \.self) { choice in
                        Text(floorLabel(choice)).tag(choice)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 120, alignment: .trailing)
            }
            
            HStack {
                Text("Cap")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Picker("", selection: Binding(get: { cap }, set: onCap)) {
                    Text("Off").tag(UsageCapChoice.none)
                    ForEach(capMinuteTags, id: \.self) { choice in
                        Text(capLabel(choice)).tag(choice)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 120, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
        .opacity(isEnabled ? 1 : 0.5)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var floorMinuteTags: [UsageFloorChoice] {
        var minutes = UsageFloorChoice.minuteOptions
        if case .minutes(let current) = floor, !minutes.contains(current) {
            minutes.append(current)
            minutes.sort()
        }
        return minutes.map { .minutes($0) }
    }
    
    private var capMinuteTags: [UsageCapChoice] {
        var minutes = UsageCapChoice.minuteOptions
        if case .minutes(let current) = cap, !minutes.contains(current) {
            minutes.append(current)
            minutes.sort()
        }
        return minutes.map { .minutes($0) }
    }
    
    private func floorLabel(_ choice: UsageFloorChoice) -> String {
        switch choice {
        case .none: return "None"
        case .once: return "Once"
        case .minutes(let minutes): return AppTimeFormatting.minutes(minutes)
        }
    }
    
    private func capLabel(_ choice: UsageCapChoice) -> String {
        switch choice {
        case .none: return "Off"
        case .minutes(let minutes): return AppTimeFormatting.minutes(minutes)
        }
    }
}

struct AddAppLimitSheet: View {
    @Environment(AppUsageService.self) private var usage
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    
    private var apps: [AppCandidate] {
        let all = usage.availableApps().filter { !usage.hasLimit(for: $0.bundleIdentifier) }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Add App", dismiss: dismiss)
            
            TextField("Search apps", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            if apps.isEmpty {
                Text(query.isEmpty ? "No more apps to add." : "No matches.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(apps) { app in
                    Button {
                        usage.addLimit(from: app)
                    } label: {
                        HStack(spacing: 10) {
                            AppIconView(path: app.path, size: 22)
                            Text(app.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("Set goal")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            
            Text("Then set a Goal (at least 20 minutes, or Once) and/or a Cap in the list. This app is in the list if you want a once-a-day check-in.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(12)
        }
    }
}

struct AddWebsiteLimitSheet: View {
    @Environment(AppUsageService.self) private var usage
    @Environment(\.dismiss) private var dismiss
    @State private var domainText = ""
    
    private var parsedDomain: String? {
        WebsiteTimeLimit.normalizedDomain(from: domainText)
    }
    
    private var canAddTyped: Bool {
        guard let domain = parsedDomain else { return false }
        return !usage.hasWebsiteLimit(for: domain)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Add Website", dismiss: dismiss)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Paste a site or type the domain")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("youtube.com", text: $domainText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addTyped)
                    Button("Add") { addTyped() }
                        .disabled(!canAddTyped)
                }
                if let domain = parsedDomain, domainText != domain {
                    Text("Will save as \(domain)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            let suggestions = usage.suggestedWebsiteHosts
            if suggestions.isEmpty {
                Text("Sites you visit in Safari or Chrome will show up here so you can cap them quickly.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                List(suggestions, id: \.self) { host in
                    Button {
                        usage.addWebsiteLimit(domain: host)
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.blue)
                            Text(host)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("Set goal")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            
            Text("Set a Goal and/or Cap after adding. Works in Zen, Safari, Chrome, Brave, Edge, and Arc. Full page addresses are not stored.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(12)
        }
    }
    
    private func addTyped() {
        guard canAddTyped, let domain = parsedDomain else { return }
        usage.addWebsiteLimit(domain: domain)
        domainText = ""
    }
}

private func sheetHeader(title: String, dismiss: DismissAction) -> some View {
    VStack(spacing: 0) {
        HStack {
            Button("Done") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            Spacer()
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Color.clear.frame(width: 36, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        Divider()
    }
}

struct AppIconView: View {
    let path: String
    var size: CGFloat = 20
    
    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
    }
    
    private var icon: NSImage {
        guard !path.isEmpty else {
            return NSWorkspace.shared.icon(forFileType: "app")
        }
        return NSWorkspace.shared.icon(forFile: path)
    }
}

/// Day-view strip when an app or website has already hit today's cap.
struct AppTimeLimitBanner: View {
    @Environment(AppUsageService.self) private var usage
    
    var body: some View {
        let overApps = usage.overLimitApps
        let overSites = usage.overLimitWebsites
        let total = overApps.count + overSites.count
        if usage.isEnabled, total > 0 {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Text(bannerText(apps: overApps, sites: overSites, total: total))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    usage.snoozeReminders()
                } label: {
                    Text(usage.isQuiet ? "Quiet" : "DND 15m")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(usage.isQuiet)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.08))
        }
    }
    
    private func bannerText(apps: [AppTimeLimit], sites: [WebsiteTimeLimit], total: Int) -> String {
        if total == 1, let app = apps.first, app.hasCap {
            return "\(app.displayName) hit its \(AppTimeFormatting.minutes(app.dailyLimitMinutes)) limit"
        }
        if total == 1, let site = sites.first, site.hasCap {
            return "\(site.domain) hit its \(AppTimeFormatting.minutes(site.dailyLimitMinutes)) limit"
        }
        return "\(total) time limits reached"
    }
}

/// Auto-updating daily floors shown on Today (Cursor ≥ 20m, open this app once, …).
struct UsageGoalsSection: View {
    @Environment(AppUsageService.self) private var usage
    
    var body: some View {
        let goals = usage.usageGoals
        if usage.isEnabled, !goals.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("Usage")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                
                ForEach(goals) { item in
                    UsageGoalRow(item: item)
                }
            }
        }
    }
}

private struct UsageGoalRow: View {
    let item: UsageGoalItem
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            if let path = item.appPath {
                AppIconView(path: path, size: 16)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 16, height: 16)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text(item.progress.summaryText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(item.progress.isOverMax ? .red : (item.status == .done ? .green : .secondary))
            }
            
            Spacer()
            
            StatusIndicator(status: item.status, size: 14)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(height: 40)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("Goals turn green when you hit the minimum. Caps stay green until you go over.")
    }
}

#Preview("App time settings") {
    AppTimeSettingsPanel(showingAddApp: .constant(false), showingAddWebsite: .constant(false))
        .environment(AppUsageService())
        .frame(width: 400, height: 500)
}
