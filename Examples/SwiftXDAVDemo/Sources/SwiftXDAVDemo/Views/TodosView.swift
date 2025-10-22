import SwiftUI
import SwiftXDAV

/// View for displaying todos/tasks
struct TodosView: View {
    @Bindable var appState: AppState
    @State private var viewModel: CalDAVViewModel?

    var body: some View {
        List {
            if let calendar = appState.selectedCalendar {
                Section {
                    Text("Calendar: \(calendar.displayName)")
                        .font(.headline)
                }
            }

            if appState.todos.isEmpty {
                if appState.isLoading {
                    ProgressView("Loading todos...")
                } else {
                    Text("No todos found")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(appState.todos, id: \.uid) { todo in
                    TodoRow(todo: todo)
                }
            }
        }
        .navigationTitle("Todos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Load Todos", action: loadTodos)
                    .disabled(appState.selectedCalendar == nil || appState.isLoading)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CalDAVViewModel(appState: appState)
            }
        }
    }

    private func loadTodos() {
        guard let calendar = appState.selectedCalendar else { return }
        Task {
            await viewModel?.loadTodos(from: calendar)
        }
    }
}

struct TodoRow: View {
    let todo: VTodo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: todo.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.status == .completed ? .green : .gray)

                Text(todo.summary ?? "Untitled Task")
                    .font(.headline)
            }

            if let status = todo.status {
                Text("Status: \(status.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let percentComplete = todo.percentComplete {
                HStack {
                    Image(systemName: "chart.bar")
                    Text("\(percentComplete)% complete")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }

            if let priority = todo.priority {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Priority: \(priority)")
                }
                .font(.caption)
                .foregroundStyle(priority <= 3 ? .red : .orange)
            }

            if let due = todo.due {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text("Due: \(formatDate(due))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let description = todo.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
