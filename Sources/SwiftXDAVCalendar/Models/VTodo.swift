import Foundation

/// iCalendar VTODO component
///
/// `VTodo` represents a to-do item or task in an iCalendar.
///
/// ## Topics
///
/// ### Creating Todos
/// - ``init(uid:dtstamp:dtstart:due:completed:summary:description:status:priority:percentComplete:)``
public struct VTodo: Sendable, Equatable {
    /// Unique identifier for this todo
    public var uid: String

    /// Date/time stamp when this todo was created or last modified
    public var dtstamp: Date

    /// Start date/time of the todo
    public var dtstart: Date?

    /// Due date/time of the todo
    public var due: Date?

    /// Completion date/time
    public var completed: Date?

    /// Short summary of the todo
    public var summary: String?

    /// Detailed description of the todo
    public var description: String?

    /// Todo status
    public var status: TodoStatus?

    /// Priority (1-9, where 1 is highest)
    public var priority: Int?

    /// Percent complete (0-100)
    public var percentComplete: Int?

    /// Initialize a VTODO
    ///
    /// - Parameters:
    ///   - uid: Unique identifier (defaults to new UUID)
    ///   - dtstamp: Date/time stamp (defaults to current date)
    ///   - dtstart: Start date/time
    ///   - due: Due date/time
    ///   - completed: Completion date/time
    ///   - summary: Todo summary
    ///   - description: Todo description
    ///   - status: Todo status
    ///   - priority: Priority (1-9)
    ///   - percentComplete: Percent complete (0-100)
    public init(
        uid: String = UUID().uuidString,
        dtstamp: Date = Date(),
        dtstart: Date? = nil,
        due: Date? = nil,
        completed: Date? = nil,
        summary: String? = nil,
        description: String? = nil,
        status: TodoStatus? = nil,
        priority: Int? = nil,
        percentComplete: Int? = nil
    ) {
        self.uid = uid
        self.dtstamp = dtstamp
        self.dtstart = dtstart
        self.due = due
        self.completed = completed
        self.summary = summary
        self.description = description
        self.status = status
        self.priority = priority
        self.percentComplete = percentComplete
    }
}

/// Todo status values
public enum TodoStatus: String, Sendable, Equatable {
    /// Todo needs action
    case needsAction = "NEEDS-ACTION"

    /// Todo is in progress
    case inProcess = "IN-PROCESS"

    /// Todo is completed
    case completed = "COMPLETED"

    /// Todo is cancelled
    case cancelled = "CANCELLED"
}
