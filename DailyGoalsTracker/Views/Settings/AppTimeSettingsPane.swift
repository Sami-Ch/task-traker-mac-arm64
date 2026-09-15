import SwiftUI

/// App Time settings pane for the Settings window - wraps the existing AppTimeSettingsPanel.
struct AppTimeSettingsPane: View {
    @Environment(AppUsageService.self) private var usage
    
    @State private var showingAddApp = false
    @State private var showingAddWebsite = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Menu {
                    Button("Add App Limit") { showingAddApp = true }
                    Button("Add Website Limit") { showingAddWebsite = true }
                } label: {
                    Label("Add Limit", systemImage: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            Divider()
            
            // Use existing panel
            AppTimeSettingsPanel(showingAddApp: $showingAddApp, showingAddWebsite: $showingAddWebsite)
        }
        .navigationTitle("App Time")
    }
    
    private var statusText: String {
        let apps = usage.limits.count
        let sites = usage.websiteLimits.count
        switch (apps, sites) {
        case (0, 0): return "No limits configured"
        case (_, 0): return "\(apps) app\(apps == 1 ? "" : "s") limited"
        case (0, _): return "\(sites) site\(sites == 1 ? "" : "s") limited"
        default: return "\(apps) apps · \(sites) sites"
        }
    }
}

#Preview {
    AppTimeSettingsPane()
        .environment(AppUsageService())
        .frame(width: 500, height: 500)
}
