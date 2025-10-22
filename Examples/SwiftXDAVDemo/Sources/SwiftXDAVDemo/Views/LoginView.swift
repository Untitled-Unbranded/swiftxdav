import SwiftUI

/// Login view for authentication
struct LoginView: View {
    @Bindable var appState: AppState
    @State private var authViewModel: AuthenticationViewModel?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Type") {
                    Picker("Type", selection: $appState.serverType) {
                        ForEach(ServerType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: appState.serverType) { _, _ in
                        appState.updateServerURL()
                    }
                }

                Section("Server Details") {
                    TextField("Server URL", text: $appState.serverURL)
                        #if os(iOS)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        #endif

                    if appState.serverType.supportsAppSpecificPassword {
                        Text("⚠️ Use an app-specific password for iCloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if appState.serverType.requiresOAuth {
                        Text("⚠️ OAuth support not implemented in this demo")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Credentials") {
                    TextField("Username", text: $appState.username)
                        #if os(iOS)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        #endif

                    SecureField("Password", text: $appState.password)
                        #if os(iOS)
                        .textContentType(.password)
                        #endif
                }

                Section {
                    Button(action: connect) {
                        if appState.isLoading {
                            ProgressView()
                        } else {
                            Text("Connect")
                        }
                    }
                    .disabled(appState.username.isEmpty || appState.password.isEmpty || appState.isLoading)
                }

                if let error = appState.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("SwiftXDAV Demo")
            .onAppear {
                if authViewModel == nil {
                    authViewModel = AuthenticationViewModel(appState: appState)
                }
            }
        }
    }

    private func connect() {
        Task {
            await authViewModel?.connect()
        }
    }
}
