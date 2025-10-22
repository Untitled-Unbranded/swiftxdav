import Foundation
import SwiftXDAV
import SwiftXDAVCalendar

/// Handles CalDAV operations
@MainActor
final class CalDAVViewModel {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func loadCalendars() async {
        guard let client = appState.calDAVClient else { return }

        appState.isLoading = true
        appState.clearError()

        do {
            let calendars = try await client.listCalendars()
            appState.calendars = calendars
        } catch let error as SwiftXDAVError {
            appState.errorMessage = "Failed to load calendars: \(error)"
        } catch {
            appState.errorMessage = "Unexpected error: \(error.localizedDescription)"
        }

        appState.isLoading = false
    }

    func loadEvents(from calendar: SwiftXDAVCalendar.Calendar) async {
        guard let client = appState.calDAVClient else { return }

        appState.isLoading = true
        appState.clearError()

        do {
            // Fetch events for the next 90 days
            let start = Date()
            let end = start.addingTimeInterval(90 * 24 * 3600)

            let events = try await client.fetchEvents(
                from: calendar,
                start: start,
                end: end
            )
            appState.events = events
            appState.selectedCalendar = calendar
        } catch let error as SwiftXDAVError {
            appState.errorMessage = "Failed to load events: \(error)"
        } catch {
            appState.errorMessage = "Unexpected error: \(error.localizedDescription)"
        }

        appState.isLoading = false
    }

    func loadTodos(from calendar: SwiftXDAVCalendar.Calendar) async {
        guard let client = appState.calDAVClient else { return }

        appState.isLoading = true
        appState.clearError()

        do {
            let todos = try await client.fetchTodos(from: calendar)
            appState.todos = todos
            appState.selectedCalendar = calendar
        } catch let error as SwiftXDAVError {
            appState.errorMessage = "Failed to load todos: \(error)"
        } catch {
            appState.errorMessage = "Unexpected error: \(error.localizedDescription)"
        }

        appState.isLoading = false
    }
}
