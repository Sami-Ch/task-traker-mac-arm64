import SwiftUI

@main
struct DailyGoalsTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Real Settings UI is an NSWindow owned by AppDelegate. The SwiftUI
        // Settings scene does not appear the first time a menu-bar app asks for it.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
