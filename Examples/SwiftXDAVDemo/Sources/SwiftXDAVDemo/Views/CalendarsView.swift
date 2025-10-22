import SwiftUI
import SwiftXDAV
import SwiftXDAVCalendar

/// View for displaying calendars
struct CalendarsView: View {
    @Bindable var appState: AppState
    @State private var viewModel: CalDAVViewModel?

    var body: some View {
        List {
            if appState.calendars.isEmpty {
                if appState.isLoading {
                    ProgressView("Loading calendars...")
                } else {
                    Text("No calendars found")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(appState.calendars, id: \.url) { calendar in
                    Button(action: { loadEvents(from: calendar) }) {
                        CalendarRow(calendar: calendar)
                    }
                }
            }
        }
        .navigationTitle("Calendars")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", action: loadCalendars)
                    .disabled(appState.isLoading)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CalDAVViewModel(appState: appState)
                loadCalendars()
            }
        }
    }

    private func loadCalendars() {
        Task {
            await viewModel?.loadCalendars()
        }
    }

    private func loadEvents(from calendar: SwiftXDAVCalendar.Calendar) {
        Task {
            await viewModel?.loadEvents(from: calendar)
        }
    }
}

struct CalendarRow: View {
    let calendar: SwiftXDAVCalendar.Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(calendar.displayName)
                .font(.headline)

            Text(calendar.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            let components = calendar.supportedComponents
            if !components.isEmpty {
                Text("Supports: \(components.map { $0.rawValue }.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
