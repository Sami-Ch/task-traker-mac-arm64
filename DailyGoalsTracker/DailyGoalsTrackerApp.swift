import SwiftUI

@main
struct DailyGoalsTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - the app is menu bar only
        Settings {
            EmptyView()
        }
    }
}
