import SwiftUI
import SwiftXDAV

/// View for displaying events
struct EventsView: View {
    @Bindable var appState: AppState

    var body: some View {
        List {
            if let calendar = appState.selectedCalendar {
                Section {
                    Text("Calendar: \(calendar.displayName)")
                        .font(.headline)
                }
            }

            if appState.events.isEmpty {
                if appState.isLoading {
                    ProgressView("Loading events...")
                } else {
                    Text("No events found")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(appState.events, id: \.uid) { event in
                    EventRow(event: event)
                }
            }
        }
        .navigationTitle("Events")
    }
}

struct EventRow: View {
    let event: VEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.summary ?? "Untitled Event")
                .font(.headline)

            if let dtstart = event.dtstart {
                HStack {
                    Image(systemName: "calendar")
                    Text(formatDate(dtstart))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let location = event.location {
                HStack {
                    Image(systemName: "location")
                    Text(location)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let description = event.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let rrule = event.rrule {
                HStack {
                    Image(systemName: "repeat")
                    Text("Recurring: \(rrule.frequency.rawValue)")
                }
                .font(.caption2)
                .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
