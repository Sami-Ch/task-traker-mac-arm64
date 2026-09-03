import AppKit
import SwiftUI
import Carbon.HIToolbox

extension Notification.Name {
    static let resetPopoverToToday = Notification.Name("resetPopoverToToday")
}

/// AppDelegate managing the menu bar status item and popover
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    
    let dataStore = DataStore()
    let prayerService = PrayerService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupGlobalHotKey()
        prayerService.bootstrap()
    }
    
    // MARK: - Status Item Setup
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Daily Goals")
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover)
            button.target = self
            
            // Right-click for quick menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    // MARK: - Popover Setup
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        
        let contentView = PopoverView()
            .environment(dataStore)
            .environment(prayerService)
        popover.contentViewController = NSHostingController(rootView: contentView)
    }
    
    // MARK: - Event Monitor (Click Outside to Close)
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
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
        guard let button = statusItem.button else { return }
        
        let event = NSApp.currentEvent
        
        // Right-click shows context menu
        if event?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        
        // Left-click toggles popover
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        // Quick status for today
        let summary = dataStore.getDailySummary(for: Date())
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
        
        menu.addItem(NSMenuItem(title: "Open Goals Tracker", action: #selector(togglePopover), keyEquivalent: "g"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Cleanup
    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
    
    // MARK: - NSPopoverDelegate
    func popoverWillShow(_ notification: Notification) {
        NotificationCenter.default.post(name: .resetPopoverToToday, object: nil)
        Task {
            await prayerService.refresh()
        }
    }
    
    func popoverDidClose(_ notification: Notification) {
        // Cleanup when popover closes
    }
}
