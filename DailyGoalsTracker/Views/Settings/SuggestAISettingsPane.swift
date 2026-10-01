import SwiftUI

/// Notes that tell Apple Intelligence how the person works and which tasks fit them.
struct SuggestAISettingsPane: View {
    @Environment(DataStore.self) private var dataStore
    @State private var notes = ""
    
    var body: some View {
        Form {
            Section {
                Text("Write how you work and which tasks actually stick. Weekly and monthly reports use this when they suggest how to make a task easier.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                ZStack(alignment: .topLeading) {
                    if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Mornings work better than nights. Short tasks stick if they are first. Quran works before anything else. I drop tasks that need more than 20 minutes unless they are the only thing on the list.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $notes)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 240)
                }
            } header: {
                Text("What works best for me")
            } footer: {
                Text("Saved on this Mac. The next report uses it. Redo on an open report rewrites the notes from the latest suggestions and from this.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            notes = dataStore.settings.workingStyleNotes
        }
        .onChange(of: notes) { _, newValue in
            guard newValue != dataStore.settings.workingStyleNotes else { return }
            dataStore.setWorkingStyleNotes(newValue)
        }
    }
}

#Preview("Suggest AI") {
    SuggestAISettingsPane()
        .environment(DataStore())
        .frame(width: 560, height: 480)
}
