import AppKit
import SwiftUI
import Carbon.HIToolbox
import UserNotifications

extension Notification.Name {
    static let resetPopoverToToday = Notification.Name("resetPopoverToToday")
    static let openSettingsWindow = Notification.Name("openSettingsWindow")
}

/// Borderless menu-bar panel. Must be able to become key so fields and buttons work.
private final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// AppDelegate managing the menu bar status item and the tasks panel.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var journalWindow: NSWindow?
    private var settingsWindow: NSWindow?
    
    private var freezeTimer: Timer?
    
    let dataStore = DataStore()
    let prayerService = PrayerService()
    let appUsageService = AppUsageService()
    let projectAlertService = ProjectAlertService()
    let periodReportService = PeriodReportService()
    let journalState = JournalWindowState()
    let settingsRouter = SettingsRouter()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        setupStatusItem()
        setupPanel()
        setupEventMonitor()
        setupGlobalHotKey()
        dataStore.prayerService = prayerService
        dataStore.projectAlertService = projectAlertService
        dataStore.periodReportService = periodReportService
        projectAlertService.attach(dataStore: dataStore)
        periodReportService.attach(dataStore: dataStore)
        prayerService.bootstrap()
        appUsageService.bootstrap()
        projectAlertService.bootstrap()
        periodReportService.bootstrap()
        dataStore.ensureDaySnapshotsCurrent()
        startFreezeTimer()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettingsFromMenu),
            name: .openSettingsWindow,
            object: nil
        )
    }
    
    // MARK: - Status Item Setup
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Daily Tasks")
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover)
            button.target = self
            
            // Right-click for quick menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    // MARK: - Panel Setup
    
    private static let panelSize = NSSize(width: 400, height: 600)
    
    private var isPanelVisible: Bool {
        panel?.isVisible == true
    }
    
    private func setupPanel() {
        let contentView = PopoverView()
            .environment(dataStore)
            .environment(prayerService)
            .environment(appUsageService)
            .environment(settingsRouter)
            .environment(\.openJournal, OpenJournalAction { [weak self] date in
                self?.showJournalWindow(for: date)
            })
        let hosting = NSHostingController(rootView: contentView)
        hosting.view.frame = NSRect(origin: .zero, size: Self.panelSize)
        hosting.view.wantsLayer = true
        hosting.view.layer?.cornerRadius = 12
        hosting.view.layer?.masksToBounds = true
        
        let panel = MenuBarPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentViewController = hosting
        self.panel = panel
    }
    
    // MARK: - Event Monitor (Click Outside to Close)
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePanelIfClickOutside(event)
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePanelIfClickOutside(event)
            return event
        }
    }
    
    private func closePanelIfClickOutside(_ event: NSEvent) {
        guard isPanelVisible, let panel else { return }
        let location = NSEvent.mouseLocation
        if panel.frame.contains(location) { return }
        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            if screenRect.contains(location) { return }
        }
        hidePanel()
    }
    
    // MARK: - Global Hotkey (Cmd+Shift+G)
    private func setupGlobalHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x44475421) // "DGT!"
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)
        
        // Install event handler
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            
            DispatchQueue.main.async {
                appDelegate.togglePopover()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
        
        // Register Cmd+Shift+G
        let modifiers = UInt32(cmdKey | shiftKey)
        let keyCode = UInt32(kVK_ANSI_Y)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    // MARK: - Actions
    @objc func togglePopover() {
        guard statusItem.button != nil else { return }
        
        let event = NSApp.currentEvent
        
        // Right-click shows context menu
        if event?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
    
    private func showPanel() {
        guard let panel, let button = statusItem.button, let buttonWindow = button.window else { return }
        
        dataStore.ensureDaySnapshotsCurrent()
        NotificationCenter.default.post(name: .resetPopoverToToday, object: nil)
        appUsageService.recordOpen()
        Task {
            await prayerService.refresh()
            dataStore.ensureDaySnapshotsCurrent()
        }
        
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let size = Self.panelSize
        var x = screenRect.midX - size.width / 2
        var y = screenRect.minY - size.height - 8
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            x = min(max(visible.minX + 8, x), visible.maxX - size.width - 8)
            y = min(max(visible.minY + 8, y), visible.maxY - size.height - 8)
        }
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func hidePanel() {
        panel?.orderOut(nil)
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        // Quick status for today
        let summary = dataStore.getDailySummary(for: dataStore.logicalDate())
        let summaryMenuItem = NSMenuItem(title: "Today: \(summary.doneCount)/\(summary.totalGoals) completed", action: nil, keyEquivalent: "")
        summaryMenuItem.isEnabled = false
        menu.addItem(summaryMenuItem)
        
        if prayerService.isEnabled, let next = prayerService.nextPrayer {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let prayerItem = NSMenuItem(
                title: "Next prayer: \(next.name.rawValue) at \(formatter.string(from: next.date))",
                action: nil,
                keyEquivalent: ""
            )
            prayerItem.isEnabled = false
            menu.addItem(prayerItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Open Tasks", action: #selector(togglePopover), keyEquivalent: "g"))
        menu.addItem(NSMenuItem(title: "Open Journal", action: #selector(openJournalFromMenu), keyEquivalent: "j"))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc func openJournalFromMenu() {
        showJournalWindow(for: dataStore.logicalDate())
    }
    
    @objc func openSettingsFromMenu() {
        showSettingsWindow()
    }
    
    func showSettingsWindow() {
        // Create the window ourselves. The SwiftUI Settings scene does not
        // exist until it has been shown once, so the first Edit Goal click
        // had nothing to order front.
        if settingsWindow == nil {
            let content = SettingsWindowView()
                .environment(dataStore)
                .environment(prayerService)
                .environment(appUsageService)
                .environment(settingsRouter)
            let hosting = NSHostingController(rootView: content)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.toolbarStyle = .unified
            window.setContentSize(NSSize(width: 780, height: 540))
            window.minSize = NSSize(width: 700, height: 460)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        
        hidePanel()
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        guard let window = settingsWindow else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        
        // Closing the popover can resign key in the same turn.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func showJournalWindow(for date: Date) {
        journalState.selectedDate = GoalEntry.startOfCivilDay(for: date)
        
        if journalWindow == nil {
            let content = JournalWindowView(state: journalState)
                .environment(dataStore)
            let hosting = NSHostingController(rootView: content)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Journal"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 560, height: 680))
            window.minSize = NSSize(width: 480, height: 460)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            journalWindow = window
        }
        
        hidePanel()
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        appUsageService.recordOpen()
        
        if let window = journalWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func startFreezeTimer() {
        freezeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.dataStore.ensureDaySnapshotsCurrent()
            Task { @MainActor in
                await self.periodReportService.checkDueReports()
            }
        }
        freezeTimer?.tolerance = 10
    }
    
    // MARK: - Cleanup
    func applicationWillTerminate(_ notification: Notification) {
        dataStore.setJournal(journalState.draftText, for: journalState.selectedDate)
        appUsageService.persist()
        freezeTimer?.invalidate()
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        handleManagedWindowWillClose(notification)
    }
    
    private func handleManagedWindowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        
        if closing === journalWindow {
            dataStore.setJournal(journalState.draftText, for: journalState.selectedDate)
        }
        
        // Stay regular while another managed window is still open
        let journalOpen = journalWindow?.isVisible == true && closing !== journalWindow
        let settingsOpen = settingsWindow?.isVisible == true && closing !== settingsWindow
        if !journalOpen && !settingsOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == AppUsageService.snoozeActionId {
            appUsageService.snoozeReminders()
        } else if ProjectAlertService.snoozeMinutes(for: response.actionIdentifier) != nil {
            projectAlertService.handleSnooze(response: response)
        } else if let reportId = PeriodReportService.reportId(from: response) {
            settingsRouter.showReport(reportId)
            showSettingsWindow()
        }
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
