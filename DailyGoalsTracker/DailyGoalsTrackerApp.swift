import SwiftUI

@main
struct DailyGoalsTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar app — Settings are opened via a managed NSWindow in AppDelegate
        // (SwiftUI Settings scenes don't appear reliably for LSUIElement apps).
        Settings {
            EmptyView()
        }
    }
}
