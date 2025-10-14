import Foundation

/// iCalendar VALARM component
///
/// `VAlarm` represents an alarm or reminder for an event or todo.
///
/// ## Topics
///
/// ### Creating Alarms
/// - ``init(action:trigger:duration:repeat:description:summary:)``
public struct VAlarm: Sendable, Equatable {
    /// Alarm action (audio, display, email)
    public var action: AlarmAction

    /// Trigger time (relative or absolute)
    public var trigger: AlarmTrigger

    /// Duration of the alarm
    public var duration: TimeInterval?

    /// Number of times to repeat the alarm
    public var `repeat`: Int?

    /// Description for display alarms
    public var description: String?

    /// Summary for email alarms
    public var summary: String?

    /// Initialize a VALARM
    ///
    /// - Parameters:
    ///   - action: Alarm action
    ///   - trigger: Trigger time
    ///   - duration: Alarm duration
    ///   - repeat: Number of repetitions
    ///   - description: Alarm description
    ///   - summary: Alarm summary
    public init(
        action: AlarmAction,
        trigger: AlarmTrigger,
        duration: TimeInterval? = nil,
        repeat: Int? = nil,
        description: String? = nil,
        summary: String? = nil
    ) {
        self.action = action
        self.trigger = trigger
        self.duration = duration
        self.repeat = `repeat`
        self.description = description
        self.summary = summary
    }
}

/// Alarm action values
public enum AlarmAction: String, Sendable, Equatable {
    /// Audio alarm (play sound)
    case audio = "AUDIO"

    /// Display alarm (show message)
    case display = "DISPLAY"

    /// Email alarm (send email)
    case email = "EMAIL"
}

/// Alarm trigger (when the alarm fires)
public enum AlarmTrigger: Sendable, Equatable {
    /// Relative trigger (e.g., "-PT15M" for 15 minutes before)
    case relative(TimeInterval)

    /// Absolute trigger (specific date/time)
    case absolute(Date)
}
