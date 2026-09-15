import SwiftUI

/// Prayer settings pane for the Settings window - wraps the existing PrayerSettingsPanel.
struct PrayerSettingsPane: View {
    @Environment(PrayerService.self) private var prayer
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                if prayer.isEnabled {
                    if let next = prayer.nextPrayer {
                        Label("Next: \(next.name.rawValue) at \(next.date, style: .time)", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Calculating prayer times...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Prayer alerts are disabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    Task { await prayer.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!prayer.isEnabled)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            Divider()
            
            // Use existing panel
            PrayerSettingsPanel()
        }
        .navigationTitle("Prayer Times")
    }
}

#Preview {
    PrayerSettingsPane()
        .environment(PrayerService())
        .frame(width: 500, height: 500)
}
