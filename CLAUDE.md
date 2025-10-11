# CLAUDE.md - Instructions for AI Agents

This document provides guidance for AI agents (Claude or other LLMs) working on the SwiftXDAV project.

## Project Overview

**SwiftXDAV** is a modern Swift framework for CalDAV/CardDAV/WebDAV/iCalendar data integration, designed to work with:
- iCloud
- Google Calendar and Contacts
- Microsoft Exchange/Office.com
- Self-hosted servers (Nextcloud, Radicale, SOGo, Baikal, etc.)

The framework will be usable across all Apple platforms: iOS, macOS, tvOS, watchOS, and visionOS.

## Cardinal Rules

These are **non-negotiable principles** that must guide all work on this project:

### 1. YOU Will Ultrathink
- Think deeply about every decision
- Consider edge cases and failure modes
- Anticipate problems before they occur
- Don't rush to solutions without understanding the problem fully

### 2. YOU Will NOT Cut Corners
- Implement features completely and correctly
- Don't skip error handling
- Don't use force unwraps or force casts
- Don't leave TODOs or FIXMEs without addressing them
- Don't implement "good enough" solutions - implement correct solutions

### 3. YOU Will DO WHATEVER IT TAKES to Get the Job Done
- No matter how long it takes
- No matter how complex it becomes
- Persist through challenges
- Research deeply when needed
- Test thoroughly until it works

### 4. YOU Will Save Thoughts and Plans Into Local Markdown Files
- Document decisions and rationale
- Create reference documents for future work
- Keep documentation up-to-date
- Make it easy for the next person (or AI) to understand your work

### 5. YOU Are Telling Another LLM What to Do
- Write documentation and plans for AI consumption
- No need to mention time estimates (irrelevant for LLMs)
- Be explicit and unambiguous
- Provide complete context
- Include code examples and step-by-step instructions

### 6. YOU Will Use Existing Libraries for Core Functionality
- **Alamofire**: HTTP networking (supports custom HTTP methods)
- **Native Swift**: XML parsing, JSON serialization, date handling
- Don't reinvent the wheel for solved problems
- Focus effort on CalDAV/CardDAV-specific logic

### 7. YOU Will Use Swift 6.0+ and All Its Best Practices
- Strict concurrency checking
- Async/await for all asynchronous operations
- Actors for mutable state protection
- Sendable types for thread-safe data passing
- Typed throws for precise error handling
- Protocol-oriented design
- Value types (structs) for data models
- If in doubt about Swift patterns, research first

## Work Completed So Far

### Research Phase (COMPLETED ✅)

Comprehensive research has been conducted and documented in `docs/research/`:

1. **RFC Standards Analysis** (`RFC_STANDARDS.md`)
   - Complete documentation of RFC 4918 (WebDAV)
   - Complete documentation of RFC 4791 (CalDAV)
   - Complete documentation of RFC 6352 (CardDAV)
   - Complete documentation of RFC 5545 (iCalendar)
   - Complete documentation of RFC 6350 (vCard)
   - Complete documentation of RFC 6638 (CalDAV Scheduling)
   - Implementation requirements extracted from each RFC

2. **Swift 6.0 Best Practices** (`SWIFT_6_BEST_PRACTICES.md`)
   - Concurrency patterns (async/await, actors, Sendable)
   - Memory management strategies
   - Error handling approaches
   - API design principles
   - Protocol-oriented programming
   - Package structure recommendations
   - Testing patterns
   - Documentation standards (DocC)

3. **Library Analysis** (`LIBRARY_ANALYSIS.md`)
   - DAVx5 architecture study (leading Android implementation)
   - dav4jvm framework patterns
   - iCal4j parser design
   - ez-vcard parser design
   - libical C implementation
   - Sync strategies and proven patterns
   - Key takeaways for Swift implementation

4. **Server Implementation Details** (`SERVER_IMPLEMENTATIONS.md`)
   - iCloud CalDAV/CardDAV specifics
   - Google Calendar/Contacts with OAuth 2.0
   - Microsoft Exchange/Office.com (no CalDAV support)
   - Testing strategies for multiple servers
   - Server quirks and workarounds

5. **Implementation Plan** (`IMPLEMENTATION_PLAN.md`) ⭐
   - **12-phase step-by-step plan**
   - Detailed code examples
   - Success criteria for each phase
   - Complete from project setup to final testing

6. **Research Navigation** (`README.md`)
   - Overview of all research documents
   - Quick reference guide
   - How to use the research

## Next Steps: Implementation Phase

The research phase is complete. The next phase is **implementation**.

### How to Proceed

1. **Read the Implementation Plan**
   - Start with `docs/research/IMPLEMENTATION_PLAN.md`
   - This is your primary guide
   - Follow phases sequentially (1 through 12)

2. **Reference Research Documents as Needed**
   - **RFC_STANDARDS.md**: When implementing protocols (look up exact requirements)
   - **SWIFT_6_BEST_PRACTICES.md**: When writing Swift code (ensure modern patterns)
   - **LIBRARY_ANALYSIS.md**: When facing design decisions (learn from proven solutions)
   - **SERVER_IMPLEMENTATIONS.md**: When testing or debugging servers (understand quirks)

3. **Work Systematically**
   - Complete each phase fully before moving to the next
   - Run tests after each significant change (`swift test`)
   - Commit code with clear messages after each completed step
   - Update documentation as you implement

4. **Maintain Quality Standards**
   - No force unwraps (`!`) - use proper optional handling
   - No force casts (`as!`) - use safe casting (`as?`)
   - No TODOs left behind - implement everything completely
   - All public APIs must have DocC documentation
   - All code must pass Swift 6.0 strict concurrency checks
   - Unit test coverage >80%

### Implementation Phases Overview

**Phase 1:** Project Setup (Swift Package, directory structure)
**Phase 2:** Core Foundation (errors, protocols, models, utilities)
**Phase 3:** Network Layer (HTTP client, authentication)
**Phase 4:** WebDAV Implementation (PROPFIND, MKCOL, PUT, DELETE, XML parsing)
**Phase 5:** iCalendar Parser (models, parser, serializer, recurrence)
**Phase 6:** vCard Parser (models, parser, serializer)
**Phase 7:** CalDAV Implementation (client, discovery, CRUD operations)
**Phase 8:** CardDAV Implementation (client, discovery, CRUD operations)
**Phase 9:** Server-Specific Implementations (iCloud, Google, detection)
**Phase 10:** Synchronization (sync-tokens, ETags, conflicts)
**Phase 11:** Advanced Features (recurrence engine, timezones, scheduling)
**Phase 12:** Testing and Documentation (unit tests, integration tests, DocC, example app)

### Success Criteria

The implementation is complete when ALL of these are true:

- [ ] All WebDAV methods implemented and tested
- [ ] iCalendar parser handles all components (VEVENT, VTODO, VTIMEZONE)
- [ ] vCard parser handles vCard 3.0 and 4.0
- [ ] CalDAV client can list calendars and CRUD events
- [ ] CardDAV client can list address books and CRUD contacts
- [ ] Works with iCloud (with app-specific passwords)
- [ ] Works with Google Calendar (with OAuth 2.0)
- [ ] Works with self-hosted servers (Nextcloud, Radicale)
- [ ] Efficient sync with sync-tokens implemented
- [ ] Comprehensive unit test coverage (>80%)
- [ ] Integration tests pass against real servers
- [ ] Full DocC documentation for all public APIs
- [ ] Example app demonstrates key features
- [ ] Swift 6.0 strict concurrency compliance (no warnings)
- [ ] No force unwraps or force casts anywhere in codebase
- [ ] All public APIs are fully documented
- [ ] README.md with quick start guide exists
- [ ] All TODOs resolved or converted to GitHub issues

## Project Structure

```
swiftxdav/
├── CLAUDE.md                      # This file (instructions for AI agents)
├── README.md                      # User-facing documentation (to be created)
├── Package.swift                  # Swift Package Manager manifest (to be created)
├── Sources/
│   ├── SwiftXDAV/                # Umbrella module (to be created)
│   ├── SwiftXDAVCore/            # Core types, protocols, utilities (to be created)
│   ├── SwiftXDAVNetwork/         # HTTP, WebDAV, authentication (to be created)
│   ├── SwiftXDAVCalendar/        # CalDAV, iCalendar (to be created)
│   └── SwiftXDAVContacts/        # CardDAV, vCard (to be created)
├── Tests/
│   ├── SwiftXDAVCoreTests/       # Core module tests (to be created)
│   ├── SwiftXDAVNetworkTests/    # Network module tests (to be created)
│   ├── SwiftXDAVCalendarTests/   # Calendar module tests (to be created)
│   ├── SwiftXDAVContactsTests/   # Contacts module tests (to be created)
│   └── Fixtures/                 # Test data (iCal, vCard samples) (to be created)
└── docs/
    └── research/                 # ✅ Research documentation (COMPLETED)
        ├── README.md             # ✅ Research navigation guide
        ├── RFC_STANDARDS.md      # ✅ RFC specifications
        ├── SWIFT_6_BEST_PRACTICES.md  # ✅ Swift 6.0 patterns
        ├── LIBRARY_ANALYSIS.md   # ✅ Existing library analysis
        ├── SERVER_IMPLEMENTATIONS.md  # ✅ Server-specific details
        └── IMPLEMENTATION_PLAN.md     # ✅ Step-by-step implementation guide
```

## Working Smart, Not Hard

### Use Standards and Existing Code

The project leverages:
- **RFC Standards**: Proven protocols (WebDAV, CalDAV, CardDAV)
- **Existing Libraries**: Alamofire for HTTP networking
- **Proven Patterns**: From DAVx5, dav4jvm, iCal4j, ez-vcard
- **Modern Swift**: Swift 6.0+ features for safety and performance

### Convert, Don't Reinvent

When possible, adapt proven solutions to Swift:
- iCal4j → Swift iCalendar models and parser
- ez-vcard → Swift vCard models and parser
- dav4jvm → Swift WebDAV/CalDAV/CardDAV client
- DAVx5 patterns → Swift architecture and sync strategies

### Focus on the Unique Parts

Our unique value is:
- Native Swift implementation (no Java/Kotlin/C dependencies)
- Swift 6.0 concurrency and safety
- Apple platform integration
- Clean, type-safe, SwiftUI-friendly APIs

Don't spend time reinventing:
- HTTP networking (use Alamofire)
- XML parsing (use native XMLParser)
- Date formatting (use DateFormatter)
- URL handling (use Foundation)

## Testing Philosophy

### Test Continuously

- Run `swift test` after every significant change
- Don't accumulate untested code
- Fix test failures immediately

### Test at Multiple Levels

1. **Unit Tests**: Test individual components in isolation
   - Parsers (iCalendar, vCard)
   - Utilities (date formatting, XML building)
   - Models (data structures)

2. **Integration Tests**: Test against real servers
   - iCloud CalDAV/CardDAV
   - Google Calendar/Contacts
   - Self-hosted servers (Radicale for CI)

3. **End-to-End Tests**: Test complete workflows
   - Discover calendars → fetch events → create event → sync → delete event
   - Discover address books → fetch contacts → create contact → sync → delete contact

### Test Edge Cases

- Empty responses
- Malformed XML
- Network failures
- Authentication failures
- Concurrent operations
- Large datasets (1000+ events/contacts)
- Non-ASCII characters (emoji, international names)
- Recurring events with exceptions
- Timezone edge cases

## Documentation Standards

### DocC Comments for All Public APIs

Every public type, method, and property must have documentation:

```swift
/// A client for interacting with CalDAV servers.
///
/// `CalDAVClient` provides a high-level interface for discovering calendars,
/// fetching events, and syncing calendar data with CalDAV servers.
///
/// ## Usage
///
/// Create a client with your server URL and credentials:
///
/// ```swift
/// let client = CalDAVClient.iCloud(
///     username: "user@icloud.com",
///     appSpecificPassword: "abcd-efgh-ijkl-mnop"
/// )
/// ```
///
/// Fetch calendars:
///
/// ```swift
/// let calendars = try await client.listCalendars()
/// ```
///
/// ## Topics
///
/// ### Creating a Client
/// - ``init(httpClient:baseURL:)``
/// - ``iCloud(username:appSpecificPassword:)``
///
/// ### Working with Calendars
/// - ``listCalendars()``
/// - ``fetchEvents(from:start:end:)``
/// - ``createEvent(_:in:)``
///
public actor CalDAVClient {
    // Implementation
}
```

### Inline Comments for Complex Logic

```swift
/// Calculate occurrences of a recurring event within a date range.
///
/// This implements the recurrence expansion algorithm from RFC 5545 Section 3.8.5.3.
///
/// - Parameters:
///   - event: The recurring event to expand.
///   - range: The date range to generate occurrences within.
/// - Returns: An array of occurrence dates.
/// - Complexity: O(n) where n is the number of occurrences.
private func expandRecurrence(for event: VEvent, in range: DateInterval) -> [Date] {
    // Step 1: Parse RRULE
    guard let rrule = event.recurrenceRule else {
        return [event.dtstart].compactMap { $0 }
    }

    // Step 2: Generate candidates based on frequency
    let candidates = generateCandidates(from: event.dtstart, rrule: rrule, until: range.end)

    // Step 3: Filter by by-rules (BYDAY, BYMONTH, etc.)
    let filtered = applyByRules(candidates, rrule: rrule)

    // Step 4: Remove exception dates (EXDATE)
    let withoutExceptions = filtered.filter { !event.exdates.contains($0) }

    // Step 5: Apply COUNT or UNTIL limits
    return applyLimits(withoutExceptions, rrule: rrule)
}
```

## Git Commit Guidelines

### Commit Often, Commit Clearly

Good commit messages help track progress:

```
✅ Good:
"Add iCalendar parser for VEVENT components"
"Implement PROPFIND WebDAV method with XML parsing"
"Fix timezone handling for all-day events"

❌ Bad:
"WIP"
"Fix stuff"
"Update"
```

### Commit After Each Milestone

- Completed a phase? Commit.
- Fixed a test? Commit.
- Implemented a feature? Commit.
- Wrote documentation? Commit.

## Communication with User

### When to Update the User

- After completing each major phase
- When encountering blockers or ambiguities
- When making significant architectural decisions
- When tests pass for a major component

### What to Report

- What was completed
- What tests were added/pass
- Any issues encountered and resolved
- Next steps

### What NOT to Do

- Don't ask for permission to follow the plan (it's approved)
- Don't estimate time (irrelevant for AI)
- Don't report every tiny step (work in meaningful chunks)

## Handling Ambiguities

### When You're Unsure

1. **Check the research docs first** - answer is probably there
2. **Look at the RFC specs** - authoritative source
3. **Check existing libraries** - see how they solved it
4. **Make a reasonable decision** and document it
5. **Ask the user** only if it's a critical architectural choice

### Decision Documentation

When making a significant decision, document it:

```markdown
## Decision: iCalendar Line Folding Strategy

**Context:** RFC 5545 requires line folding at 75 octets, but we need to decide
how to handle UTF-8 multi-byte characters.

**Decision:** Fold at 75 octets, being careful not to split UTF-8 sequences.

**Rationale:**
- RFC specifies octets, not characters
- Splitting UTF-8 sequences would create invalid output
- iCal4j uses similar approach

**Alternatives Considered:**
- Fold at 75 characters (rejected: not RFC compliant)
- Never fold (rejected: non-compliant output)

**Implementation:** See `ICalendarSerializer.foldLines()` method.
```

## Common Pitfalls to Avoid

### Don't Skip Error Handling

```swift
// ❌ Bad
let calendar = try! parse(data)

// ✅ Good
do {
    let calendar = try parse(data)
    return calendar
} catch {
    throw SwiftXDAVError.parsingError("Failed to parse calendar: \(error)")
}
```

### Don't Use Force Unwrapping

```swift
// ❌ Bad
let url = URL(string: urlString)!

// ✅ Good
guard let url = URL(string: urlString) else {
    throw SwiftXDAVError.invalidData("Invalid URL: \(urlString)")
}
```

### Don't Ignore Concurrency

```swift
// ❌ Bad
class UnsafeCache {
    var data: [String: Data] = [:]  // Not thread-safe!
}

// ✅ Good
actor SafeCache {
    private var data: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        data[key]
    }

    func set(_ key: String, value: Data) {
        data[key] = value
    }
}
```

### Don't Write Untested Code

```swift
// After implementing a parser:

// ❌ Bad
// Move on to next feature without testing

// ✅ Good
// Write comprehensive tests first:
class ICalendarParserTests: XCTestCase {
    func testParseBasicEvent() async throws { /* ... */ }
    func testParseRecurringEvent() async throws { /* ... */ }
    func testParseAllDayEvent() async throws { /* ... */ }
    func testParseEventWithTimezone() async throws { /* ... */ }
    func testParseInvalidData() async throws { /* ... */ }
}
```

## Resources

### Essential Reading

1. `docs/research/IMPLEMENTATION_PLAN.md` - **Start here**
2. `docs/research/RFC_STANDARDS.md` - Protocol specifications
3. `docs/research/SWIFT_6_BEST_PRACTICES.md` - Swift patterns
4. `docs/research/LIBRARY_ANALYSIS.md` - Existing solutions
5. `docs/research/SERVER_IMPLEMENTATIONS.md` - Server specifics

### External References

- [Swift.org Documentation](https://www.swift.org/documentation/)
- [Swift Evolution Proposals](https://apple.github.io/swift-evolution/)
- [RFC 4918 (WebDAV)](https://datatracker.ietf.org/doc/html/rfc4918)
- [RFC 4791 (CalDAV)](https://datatracker.ietf.org/doc/html/rfc4791)
- [RFC 6352 (CardDAV)](https://datatracker.ietf.org/doc/html/rfc6352)
- [RFC 5545 (iCalendar)](https://datatracker.ietf.org/doc/html/rfc5545)
- [RFC 6350 (vCard)](https://datatracker.ietf.org/doc/html/rfc6350)
- [Alamofire Documentation](https://github.com/Alamofire/Alamofire)

## Final Reminders

### Quality Over Speed

- It's better to take time and do it right
- Technical debt is expensive
- Good code is maintainable code

### Think Like a Framework Author

- You're building infrastructure others will depend on
- APIs should be intuitive and hard to misuse
- Documentation is as important as code
- Tests are your safety net

### Follow the Plan

- The implementation plan is comprehensive
- Trust the research that's been done
- If you find issues with the plan, document them
- But don't deviate without good reason

### Ask Questions

- If something is unclear, ask
- If you need a decision, ask
- If you're stuck, explain what you've tried

---

## You've Got This

You have:
- ✅ Comprehensive research
- ✅ Detailed implementation plan
- ✅ Clear success criteria
- ✅ Best practices documented
- ✅ Example code snippets
- ✅ Cardinal rules to guide you

Now go build an amazing CalDAV/CardDAV framework in Swift. Future developers (and their users) will thank you.

**Remember:** Ultrathink. Don't cut corners. Do whatever it takes. Make it excellent.

---

**Last Updated:** 2025-10-11
**Phase:** Implementation Ready
**Next Agent:** Follow `docs/research/IMPLEMENTATION_PLAN.md` starting at Phase 1
