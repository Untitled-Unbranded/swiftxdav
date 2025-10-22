import SwiftUI

/// Settings view with disconnect option
struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        List {
            Section("Connection") {
                LabeledContent("Server Type", value: appState.serverType.rawValue)
                LabeledContent("Server URL", value: appState.serverURL)
                LabeledContent("Username", value: appState.username)
            }

            Section("Statistics") {
                LabeledContent("Calendars", value: "\(appState.calendars.count)")
                LabeledContent("Events", value: "\(appState.events.count)")
                LabeledContent("Todos", value: "\(appState.todos.count)")
                LabeledContent("Address Books", value: "\(appState.addressBooks.count)")
                LabeledContent("Contacts", value: "\(appState.contacts.count)")
            }

            if let error = appState.errorMessage {
                Section("Last Error") {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                Button("Clear Data", role: .destructive, action: clearData)
                Button("Disconnect", role: .destructive, action: disconnect)
            }
        }
        .navigationTitle("Settings")
    }

    private func clearData() {
        appState.clearData()
    }

    private func disconnect() {
        appState.disconnect()
    }
}
