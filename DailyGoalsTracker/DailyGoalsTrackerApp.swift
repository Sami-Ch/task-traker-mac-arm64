import AppKit
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
            CommandGroup(after: .textEditing) {
                Button("Show Spelling and Grammar") {
                    NSApp.sendAction(#selector(NSText.showGuessPanel(_:)), to: nil, from: nil)
                }
                Button("Check Document Now") {
                    NSApp.sendAction(#selector(NSTextView.checkTextInDocument(_:)), to: nil, from: nil)
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
