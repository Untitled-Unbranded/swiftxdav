import Foundation
import SwiftXDAV

/// Handles authentication and client creation
@MainActor
final class AuthenticationViewModel {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func connect() async {
        appState.isLoading = true
        appState.clearError()

        do {
            // Create HTTP client
            let httpClient = AuthenticatedHTTPClient(
                baseClient: AlamofireHTTPClient(),
                authentication: .basic(
                    username: appState.username,
                    password: appState.password
                )
            )

            // Create base URL
            guard let baseURL = URL(string: appState.serverURL) else {
                throw SwiftXDAVError.invalidData("Invalid URL: \(appState.serverURL)")
            }

            // Create clients
            let calDAVClient = CalDAVClient(
                httpClient: httpClient,
                baseURL: baseURL
            )

            let cardDAVClient = CardDAVClient(
                httpClient: httpClient,
                baseURL: baseURL
            )

            // Test connection by discovering principal
            _ = try await calDAVClient.discoverPrincipal()

            // Success - save clients
            appState.calDAVClient = calDAVClient
            appState.cardDAVClient = cardDAVClient
            appState.isAuthenticated = true

        } catch let error as SwiftXDAVError {
            appState.errorMessage = formatError(error)
        } catch {
            appState.errorMessage = "Unexpected error: \(error.localizedDescription)"
        }

        appState.isLoading = false
    }

    private func formatError(_ error: SwiftXDAVError) -> String {
        switch error {
        case .authenticationRequired:
            return "Authentication required. Please check your credentials."
        case .unauthorized:
            return "Unauthorized. Your account may not have CalDAV/CardDAV access."
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .invalidResponse(let statusCode, _):
            return "Invalid response from server (status \(statusCode))"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        default:
            return "Error: \(error)"
        }
    }
}
