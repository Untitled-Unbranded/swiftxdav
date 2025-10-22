import SwiftUI

/// Main content view with tab navigation
struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        if appState.isAuthenticated {
            #if os(macOS)
            NavigationSplitView {
                Sidebar(appState: appState)
            } detail: {
                Text("Select an item from the sidebar")
                    .foregroundStyle(.secondary)
            }
            #else
            TabView {
                NavigationStack {
                    CalendarsView(appState: appState)
                }
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }

                NavigationStack {
                    EventsView(appState: appState)
                }
                .tabItem {
                    Label("Events", systemImage: "calendar.circle")
                }

                NavigationStack {
                    TodosView(appState: appState)
                }
                .tabItem {
                    Label("Todos", systemImage: "checklist")
                }

                NavigationStack {
                    AddressBooksView(appState: appState)
                }
                .tabItem {
                    Label("Address Books", systemImage: "book")
                }

                NavigationStack {
                    ContactsView(appState: appState)
                }
                .tabItem {
                    Label("Contacts", systemImage: "person.2")
                }

                NavigationStack {
                    SettingsView(appState: appState)
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            }
            #endif
        } else {
            LoginView(appState: appState)
        }
    }
}

#if os(macOS)
struct Sidebar: View {
    @Bindable var appState: AppState
    @State private var selection: SidebarItem? = .calendars

    enum SidebarItem: String, Identifiable, CaseIterable {
        case calendars = "Calendars"
        case events = "Events"
        case todos = "Todos"
        case addressBooks = "Address Books"
        case contacts = "Contacts"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .calendars: return "calendar"
            case .events: return "calendar.circle"
            case .todos: return "checklist"
            case .addressBooks: return "book"
            case .contacts: return "person.2"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        .navigationDestination(for: SidebarItem.self) { item in
            destinationView(for: item)
        }
    }

    @ViewBuilder
    private func destinationView(for item: SidebarItem) -> some View {
        switch item {
        case .calendars:
            CalendarsView(appState: appState)
        case .events:
            EventsView(appState: appState)
        case .todos:
            TodosView(appState: appState)
        case .addressBooks:
            AddressBooksView(appState: appState)
        case .contacts:
            ContactsView(appState: appState)
        case .settings:
            SettingsView(appState: appState)
        }
    }
}
#endif
