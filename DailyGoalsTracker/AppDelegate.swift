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
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var journalWindow: NSWindow?
    private var settingsWindow: NSWindow?
    
    private var freezeTimer: Timer?
    /// The click that opens the panel is also seen by the outside-click monitor.
    private var ignoreOutsideClicksUntil = Date.distantPast
    
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reregisterGlobalHotKeys),
            name: .keyboardShortcutsDidChange,
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
            // Mouse-up never arrives on the status item, so the click did nothing.
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
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
        panel.level = .popUpMenu
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
        if Date() < ignoreOutsideClicksUntil { return }
        if event.window === statusItem.button?.window { return }
        let location = NSEvent.mouseLocation
        if panel.frame.contains(location) { return }
        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            if screenRect.contains(location) { return }
        }
        hidePanel()
    }
    
    // MARK: - Global Hotkeys
    private var didInstallHotKeyHandler = false
    
    private func setupGlobalHotKey() {
        if !didInstallHotKeyHandler {
            var eventType = EventTypeSpec()
            eventType.eventClass = OSType(kEventClassKeyboard)
            eventType.eventKind = UInt32(kEventHotKeyPressed)
            
            InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                DispatchQueue.main.async {
                    switch hotKeyID.id {
                    case 1:
                        appDelegate.togglePopover()
                    case 2:
                        appDelegate.openJournalFromMenu()
                    case 3:
                        appDelegate.insertTasksIntoJournal()
                    default:
                        break
                    }
                }
                return noErr
            }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
            didInstallHotKeyHandler = true
        }
        
        reregisterGlobalHotKeys()
    }
    
    @objc private func reregisterGlobalHotKeys() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
        
        let shortcuts = dataStore.settings.shortcuts
        registerHotKey(id: 1, chord: shortcuts.openTasks)
        registerHotKey(id: 2, chord: shortcuts.openJournal)
        registerHotKey(id: 3, chord: shortcuts.insertJournalTasks)
    }
    
    private func registerHotKey(id: UInt32, chord: KeyChord) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x44475421) // "DGT!"
        hotKeyID.id = id
        var ref: EventHotKeyRef?
        RegisterEventHotKey(
            UInt32(chord.keyCode),
            chord.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if let ref {
            hotKeyRefs.append(ref)
        }
    }
    
    // MARK: - Actions
    @objc func togglePopover() {
        guard statusItem.button != nil else { return }
        
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseDown || event?.type == .rightMouseUp {
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
        // A menu-bar app is not active, so makeKeyAndOrderFront leaves the panel hidden.
        ignoreOutsideClicksUntil = Date().addingTimeInterval(0.25)
        panel.orderFrontRegardless()
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
        
        menu.addItem(menuItem(title: "Open Tasks", action: #selector(togglePopover), chord: dataStore.settings.shortcuts.openTasks))
        menu.addItem(menuItem(title: "Open Journal", action: #selector(openJournalFromMenu), chord: dataStore.settings.shortcuts.openJournal))
        menu.addItem(menuItem(title: "Add Tasks to Journal", action: #selector(insertTasksIntoJournal), chord: dataStore.settings.shortcuts.insertJournalTasks))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    private func menuItem(title: String, action: Selector, chord: KeyChord) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: chord.menuKeyEquivalent)
        if !chord.menuKeyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = chord.nsEventModifiers
        }
        return item
    }
    
    @objc func openJournalFromMenu() {
        showJournalWindow(for: dataStore.logicalDate())
    }
    
    @objc func insertTasksIntoJournal() {
        if journalWindow?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            journalWindow?.makeKeyAndOrderFront(nil)
            NotificationCenter.default.post(name: .insertJournalTaskTemplate, object: nil)
        } else {
            journalState.pendingTaskTemplate = true
            showJournalWindow(for: dataStore.logicalDate())
        }
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
            window.collectionBehavior.insert(.fullScreenPrimary)
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
        journalState.flush?()
        appUsageService.persist()
        freezeTimer?.invalidate()
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
    }
    
    func windowWillClose(_ notification: Notification) {
        handleManagedWindowWillClose(notification)
    }
    
    private func handleManagedWindowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        
        if closing === journalWindow {
            journalState.flush?()
            dataStore.lockJournal()
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
