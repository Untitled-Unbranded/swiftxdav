import SwiftUI

@main
struct SwiftXDAVDemoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .alert("Error", isPresented: .init(
                    get: { appState.errorMessage != nil },
                    set: { if !$0 { appState.clearError() } }
                )) {
                    Button("OK", role: .cancel) {
                        appState.clearError()
                    }
                } message: {
                    if let error = appState.errorMessage {
                        Text(error)
                    }
                }
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #endif
    }
}
