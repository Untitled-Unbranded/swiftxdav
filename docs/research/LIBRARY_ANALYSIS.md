# Library Analysis: DAVx5 and Related Projects

This document analyzes existing CalDAV/CardDAV implementations to extract patterns, architectures, and approaches that can inform SwiftXDAV development.

## Table of Contents

1. [DAVx5 Architecture](#davx5-architecture)
2. [dav4jvm - WebDAV/CalDAV/CardDAV Framework](#dav4jvm)
3. [iCal4j - iCalendar Parser](#ical4j)
4. [ez-vcard - vCard Parser](#ez-vcard)
5. [libical - iCalendar Implementation](#libical)
6. [cert4android - Certificate Management](#cert4android)
7. [synctools - Android Sync Utilities](#synctools)
8. [Python CalDAV Libraries](#python-caldav-libraries)
9. [Key Takeaways for SwiftXDAV](#key-takeaways)

---

## DAVx5 Architecture

**Repository:** https://github.com/bitfireAT/davx5-ose
**Language:** Kotlin/Java
**License:** GPLv3
**Documentation:** https://bitfireAT.gitlab.io/davx5-ose/dokka/app/

### Overview

DAVx5 is the leading open-source CalDAV/CardDAV suite and sync app for Android. It provides:
- CalDAV calendar synchronization
- CardDAV contact synchronization
- WebDAV file access
- Android Sync Adapter integration
- Task synchronization (via OpenTasks/Tasks.org)

### Modular Architecture

DAVx5 has outsourced functionality into separate libraries:

1. **cert4android**: Custom certificate management
2. **dav4jvm**: WebDAV/CalDAV/CardDAV framework
3. **synctools**: iCalendar/vCard/Tasks processing and content provider access

This modular approach separates concerns:
- **Network layer** (dav4jvm)
- **Data parsing** (external libraries)
- **Platform integration** (synctools)
- **Security** (cert4android)

### Key Dependencies

**Network & Protocol:**
- **okhttp**: HTTP client (Apache License 2.0)
- **dav4jvm**: WebDAV/CalDAV/CardDAV implementation

**Data Parsing:**
- **iCal4j**: iCalendar parsing (New BSD License)
- **ez-vcard**: vCard parsing (New BSD License)

**Utilities:**
- **dnsjava**: DNS lookups for service discovery (BSD License)

### Architecture Layers

```
┌─────────────────────────────────────────┐
│         Android UI & Activities         │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│       Sync Adapter Implementation       │
│   (Android Sync Framework Integration)  │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│          Business Logic Layer           │
│  - Account Management                   │
│  - Sync Logic                           │
│  - Conflict Resolution                  │
└─────────────────────────────────────────┘
                    │
├──────────────────┬────────────────┬──────┤
│                  │                │      │
▼                  ▼                ▼      ▼
┌──────────┐  ┌──────────┐  ┌─────────┐  ┌──────────┐
│ dav4jvm  │  │ synctools│  │ iCal4j  │  │ ez-vcard │
│ (Network)│  │(Android) │  │(iCal)   │  │ (vCard)  │
└──────────┘  └──────────┘  └─────────┘  └──────────┘
     │
┌──────────┐
│  okhttp  │
│  (HTTP)  │
└──────────┘
```

### Key Design Patterns

**1. Repository Pattern**
- Separates data access from business logic
- `LocalCalendarRepository` for local storage
- `RemoteCalendarRepository` for network access

**2. Sync Adapter Pattern**
- Android-specific sync framework integration
- Handles periodic sync, conflict resolution, and sync state

**3. Service Discovery**
- Uses DNS SRV records for automatic server discovery
- Probes `.well-known` URLs for CalDAV/CardDAV endpoints

**4. Error Handling**
- Comprehensive error types for different failure scenarios
- Retry logic with exponential backoff
- User-friendly error messages

### Sync Strategy

DAVx5 implements a sophisticated sync strategy:

1. **Initial Discovery**
   - Find calendar/addressbook home URL
   - Enumerate collections (calendars, address books)

2. **Change Detection**
   - Use sync-token for efficient delta sync (if supported)
   - Fallback to ETag-based change detection
   - Compare local vs remote state

3. **Three-Way Merge**
   - Track local modifications since last sync
   - Track remote modifications since last sync
   - Resolve conflicts (usually "server wins" or "user decides")

4. **Batch Operations**
   - Group multiple changes for efficiency
   - Use multiget REPORT for fetching multiple resources

5. **State Management**
   - Store sync tokens, ETags, and modification times
   - Track sync status per calendar/address book

### Lessons for SwiftXDAV

**Adopt:**
- Modular architecture (separate network, parsing, business logic)
- Comprehensive error handling
- Service discovery via .well-known and DNS
- Efficient sync with tokens and ETags
- Batch operations for performance

**Adapt:**
- Android Sync Adapter → Swift/iOS equivalent (EventKit, Contacts framework)
- Kotlin coroutines → Swift async/await
- Java libraries → Swift equivalents or ports

---

## dav4jvm

**Repository:** https://github.com/bitfireAT/dav4jvm
**Language:** Kotlin
**License:** Mozilla Public License v2.0
**Documentation:** https://bitfireat.github.io/dav4jvm/

### Overview

dav4jvm is a WebDAV/CalDAV/CardDAV library for the JVM, originally developed for DAVx5.

### Key Features

- Full WebDAV support (RFC 4918)
- CalDAV support (RFC 4791)
- CardDAV support (RFC 6352)
- Property handling (live and dead properties)
- REPORT method queries
- Multi-status response parsing
- ETag and sync-token support

### Architecture

**Core Classes:**

```kotlin
// HTTP client wrapper
class DavResource(
    val httpClient: OkHttpClient,
    val location: HttpUrl
) {
    fun propfind(depth: Int, reqProp: Array<Property.Name>): Response
    fun report(body: String): Response
    fun get(accept: String): Response
    fun put(body: RequestBody, ifETag: String?): Response
    fun delete(): Response
}

// Property system
abstract class Property {
    abstract class Name(val namespace: String, val name: String)
    companion object {
        val factories: MutableList<PropertyFactory>
    }
}

// CalDAV specific
class CalendarHomeSet : Property {
    val hrefs: List<HttpUrl>
}

class CalendarData : Property {
    val iCalendar: String
}

// Response parsing
class MultiStatus {
    val responses: List<Response>
    class Response(
        val href: HttpUrl,
        val status: List<Status>,
        val properties: List<Property>
    )
}
```

### XML Parsing Strategy

dav4jvm uses XmlPullParser for efficient streaming XML parsing:

```kotlin
class DavResponseParser(private val parser: XmlPullParser) {
    fun parse(): MultiStatus {
        // Streaming parse of multi-status responses
        while (parser.next() != XmlPullParser.END_DOCUMENT) {
            when (parser.eventType) {
                XmlPullParser.START_TAG -> handleStartTag()
                XmlPullParser.END_TAG -> handleEndTag()
                XmlPullParser.TEXT -> handleText()
            }
        }
    }
}
```

### Property Factory Pattern

Properties use a factory pattern for extensibility:

```kotlin
interface PropertyFactory {
    fun getName(): Property.Name
    fun create(parser: XmlPullParser): Property?
}

// Register custom properties
Property.factories.add(MyCustomPropertyFactory())
```

### Key Methods Implementation

**PROPFIND:**
```kotlin
fun propfind(depth: Int, reqProp: Array<Property.Name>): Response {
    val body = buildPropfindRequest(reqProp)
    return httpClient.newCall(
        Request.Builder()
            .url(location)
            .method("PROPFIND", body)
            .header("Depth", depth.toString())
            .build()
    ).execute()
}
```

**Calendar Query:**
```kotlin
fun calendarQuery(
    component: String,
    start: Instant,
    end: Instant
): List<DavResource> {
    val query = buildCalendarQuery(component, start, end)
    val response = report(query)
    return parseMultiStatus(response).responses.map { resp ->
        DavResource(httpClient, resp.href)
    }
}
```

### Lessons for SwiftXDAV

**Adopt:**
- Property factory pattern for extensibility
- Streaming XML parsing
- Resource-oriented API (DavResource wraps URL + client)
- Multi-status response handling

**Implement in Swift:**
```swift
// Swift equivalent structure
actor DavResource {
    let httpClient: HTTPClient
    let location: URL

    func propfind(depth: Int, properties: [PropertyName]) async throws -> PropfindResponse

    func report(_ body: Data) async throws -> MultiStatusResponse

    func get() async throws -> (Data, HTTPHeaders)

    func put(_ data: Data, ifMatch etag: String?) async throws -> HTTPHeaders

    func delete() async throws
}
```

---

## iCal4j

**Repository:** https://github.com/ical4j/ical4j
**Language:** Java
**License:** BSD-style
**Website:** https://www.ical4j.org/

### Overview

iCal4j is a Java library for parsing and building iCalendar data models. It's the de-facto standard for iCalendar handling in Java/Kotlin projects.

### Core Architecture

**Component Hierarchy:**
```java
// Base class for all calendar components
abstract class Component {
    PropertyList properties;
    ComponentList subComponents;
}

class VEvent extends Component {
    // VEVENT specific methods
}

class VToDo extends Component {
    // VTODO specific methods
}

class VTimeZone extends Component {
    // VTIMEZONE specific methods
}
```

**Property System:**
```java
abstract class Property {
    String name;
    ParameterList parameters;
    String value;
}

class Summary extends Property {
    Summary(String value) {
        super("SUMMARY", value);
    }
}

class DtStart extends Property {
    DateTime dateTime;
    // ...
}
```

### Parsing Strategy

iCal4j uses a builder pattern for parsing:

```java
// Relaxed parsing (tolerates non-compliant iCalendars)
CalendarBuilder builder = new CalendarBuilder();
Calendar calendar = builder.build(inputStream);

// Access components
for (VEvent event : calendar.getComponents(Component.VEVENT)) {
    Summary summary = event.getProperty(Property.SUMMARY);
    DtStart start = event.getProperty(Property.DTSTART);
}
```

### Recurrence Handling

iCal4j has sophisticated recurrence support:

```java
// Parse RRULE
RRule rrule = new RRule("FREQ=WEEKLY;BYDAY=MO,WE,FR");

// Calculate occurrences
Date startDate = /* event start */;
Date endDate = /* end of range */;
DateList dates = rrule.getRecur().getDates(
    startDate,
    new Period(startDate, endDate),
    Value.DATE_TIME
);

// dates contains all occurrences within the period
```

### Timezone Support

iCal4j approaches timezones in two ways:

1. **Embedded VTIMEZONE definitions** (preferred)
   - iCalendar file includes full timezone rules
   - iCal4j parses and uses these definitions

2. **System timezone fallback**
   - If VTIMEZONE not present, fall back to Java TimeZone
   - Requires timezone registry

```java
// Register timezone registry
TimeZoneRegistry registry = TimeZoneRegistryFactory.getInstance().createRegistry();
TimeZone tz = registry.getTimeZone("America/New_York");
```

### Validation

iCal4j provides validation:

```java
ValidationResult result = calendar.validate();
for (ValidationEntry entry : result.getEntries()) {
    System.err.println(entry.getMessage());
}
```

### Lessons for SwiftXDAV

**Adopt:**
- Component hierarchy (base class + specific subclasses)
- Property list abstraction
- Parameter handling
- Relaxed parsing with validation
- Recurrence calculation engine

**Implement in Swift:**
```swift
// Swift equivalent
protocol CalendarComponent {
    var properties: [Property] { get }
    var subComponents: [CalendarComponent] { get }
}

struct VEvent: CalendarComponent {
    var properties: [Property]
    var subComponents: [CalendarComponent]

    var summary: String? {
        properties.first { $0.name == "SUMMARY" }?.value
    }

    var start: Date? {
        properties.first { $0.name == "DTSTART" }?.dateValue
    }
}

struct RecurrenceRule {
    let frequency: Frequency
    let interval: Int
    let count: Int?
    let until: Date?

    func occurrences(from start: Date, until end: Date) -> [Date] {
        // Calculate occurrences
    }
}
```

---

## ez-vcard

**Repository:** https://github.com/mangstadt/ez-vcard
**Language:** Java
**License:** BSD-style
**Documentation:** https://github.com/mangstadt/ez-vcard/wiki

### Overview

ez-vcard is a vCard parser library for Java with full support for vCard 2.1, 3.0, and 4.0 specifications.

### Core Features

- Streaming parser (low memory footprint)
- Full vCard 2.1, 3.0, and 4.0 support
- XML (xCard) and JSON (jCard) support
- HTML (hCard) support
- Automatic version detection
- Extensible with custom properties

### Architecture

**VCard Model:**
```java
class VCard {
    FormattedName formattedName;  // FN (required)
    StructuredName structuredName;  // N
    List<Email> emails;
    List<Telephone> telephoneNumbers;
    List<Address> addresses;
    // ... other properties

    List<RawProperty> extendedProperties;  // Custom properties
}

// Property base class
abstract class VCardProperty {
    String group;  // Property group
    List<VCardParameter> parameters;
}
```

### Parsing Strategy

**Streaming Parser:**
```java
// Streaming parse (memory efficient)
VCardReader reader = new VCardReader(inputStream);
VCard vcard;
while ((vcard = reader.readNext()) != null) {
    // Process each vCard
    String name = vcard.getFormattedName().getValue();
    List<Email> emails = vcard.getEmails();
}
reader.close();
```

**DOM Parser (for single vCards):**
```java
// Parse single vCard
String vcardString = "BEGIN:VCARD\n...END:VCARD";
VCard vcard = Ezvcard.parse(vcardString).first();
```

### Version Handling

ez-vcard automatically detects vCard version:

```java
// Automatic version detection
VCard vcard = Ezvcard.parse(vcardString).first();
VCardVersion version = vcard.getVersion();  // 2.1, 3.0, or 4.0

// Force specific version
VCard vcard = Ezvcard.parse(vcardString).version(VCardVersion.V4_0).first();
```

### Writing vCards

**String Generation:**
```java
VCard vcard = new VCard();
vcard.setFormattedName("John Doe");
vcard.addEmail("john@example.com");

String vcardString = Ezvcard.write(vcard).go();
```

**Version-Specific Output:**
```java
// Generate vCard 3.0
String vcard3 = Ezvcard.write(vcard).version(VCardVersion.V3_0).go();

// Generate vCard 4.0
String vcard4 = Ezvcard.write(vcard).version(VCardVersion.V4_0).go();
```

### Property Parameters

Handles vCard parameters elegantly:

```java
Email email = new Email("john@work.com");
email.addType(EmailType.WORK);
email.setPref(1);  // Preference parameter

Telephone tel = new Telephone("+1-555-1234");
tel.addType(TelephoneType.CELL);
tel.addType(TelephoneType.VOICE);
```

### Custom Properties

Extensible for custom properties:

```java
class MyCustomProperty extends VCardProperty {
    private String value;

    MyCustomProperty(String value) {
        this.value = value;
    }
}

// Register factory
VCardReader reader = new VCardReader(inputStream);
reader.registerScribe(new MyCustomPropertyScribe());
```

### Error Handling

Graceful error handling:

```java
VCardReader reader = new VCardReader(inputStream);
VCard vcard = reader.readNext();

// Check for parse warnings
List<String> warnings = reader.getWarnings();
for (String warning : warnings) {
    System.err.println(warning);
}
```

### Lessons for SwiftXDAV

**Adopt:**
- Streaming parser for memory efficiency
- Automatic version detection
- Graceful error handling with warnings
- Extensibility for custom properties
- Type-safe property access

**Implement in Swift:**
```swift
// Swift equivalent
struct VCard: Codable {
    var formattedName: String  // FN - required
    var name: StructuredName?  // N
    var emails: [Email] = []
    var telephones: [Telephone] = []
    var addresses: [Address] = []

    var customProperties: [String: String] = [:]
}

struct Email {
    var address: String
    var types: Set<EmailType>
    var preference: Int?
}

// Streaming parser
class VCardReader {
    func readNext() throws -> VCard? {
        // Streaming parse
    }

    var warnings: [String] { /* parse warnings */ }
}

// Usage
let reader = VCardReader(data: data)
while let vcard = try reader.readNext() {
    print("Parsed: \(vcard.formattedName)")
}
```

---

## libical

**Repository:** https://github.com/libical/libical
**Language:** C
**License:** MPL 2.0 or LGPL 2.1
**Website:** https://libical.github.io/libical/

### Overview

libical is a C library implementing iCalendar protocols (RFC5545, RFC5546, RFC7529, RFC6638, RFC7986, RFC6047).

### Architecture

**Component-Based:**
```c
// Create calendar
icalcomponent *calendar = icalcomponent_new(ICAL_VCALENDAR_COMPONENT);

// Create event
icalcomponent *event = icalcomponent_new(ICAL_VEVENT_COMPONENT);

// Add properties
icalproperty *summary = icalproperty_new_summary("Team Meeting");
icalcomponent_add_property(event, summary);

// Add event to calendar
icalcomponent_add_component(calendar, event);

// Serialize
char *ical_string = icalcomponent_as_ical_string(calendar);
```

### Property Handling

Type-safe property accessors:

```c
// Get property value
icalproperty *prop = icalcomponent_get_first_property(event, ICAL_SUMMARY_PROPERTY);
const char *summary = icalproperty_get_summary(prop);

// Set property value
icalproperty_set_summary(prop, "New Summary");
```

### Recurrence

Comprehensive recurrence support:

```c
// Parse recurrence rule
struct icalrecurrencetype recur;
recur = icalrecurrencetype_from_string("FREQ=WEEKLY;BYDAY=MO,WE,FR");

// Create recurrence iterator
icalrecur_iterator *iter = icalrecur_iterator_new(recur, dtstart);

// Iterate occurrences
struct icaltimetype next;
while (!icaltime_is_null_time(next = icalrecur_iterator_next(iter))) {
    // Process occurrence
}
icalrecur_iterator_free(iter);
```

### Timezone Handling

Built-in timezone support:

```c
// Get timezone
icaltimezone *tz = icaltimezone_get_builtin_timezone("America/New_York");

// Convert time to timezone
struct icaltimetype utc_time = icaltime_current_time_with_zone(icaltimezone_get_utc_timezone());
struct icaltimetype local_time = icaltime_convert_to_zone(utc_time, tz);
```

### Memory Management

Manual memory management (C library):

```c
// Create
icalcomponent *cal = icalcomponent_new(ICAL_VCALENDAR_COMPONENT);

// Use...

// Clean up
icalcomponent_free(cal);
```

### Lessons for SwiftXDAV

**Concepts to Adopt:**
- Component-based architecture
- Type-safe property accessors
- Iterator pattern for recurrence
- Built-in timezone support

**Avoid:**
- Manual memory management (Swift handles this)
- C string handling (use Swift String)
- Direct pointer manipulation

**Translation to Swift:**
```swift
// Swift equivalent - safer and more ergonomic
class ICalendar {
    var components: [Component] = []

    func addComponent(_ component: Component) {
        components.append(component)
    }

    func serialize() -> String {
        // Generate iCalendar string
    }
}

class VEvent: Component {
    var summary: String?
    var start: Date?
    var end: Date?

    // Type-safe accessors
}

// Recurrence iterator
struct RecurrenceIterator: Sequence, IteratorProtocol {
    let rule: RecurrenceRule
    var current: Date

    mutating func next() -> Date? {
        // Calculate next occurrence
    }
}
```

---

## cert4android

**Repository:** https://github.com/bitfireAT/cert4android
**Language:** Kotlin
**License:** GPLv3

### Overview

cert4android is an Android service + TrustManager for managing custom certificates in an app-private key store.

### Key Features

- Custom certificate management
- User-installable certificates
- Certificate trust decisions
- Bypassing system certificate store restrictions

### Use Case

Android restricts user-installed certificates from being trusted by apps. cert4android allows DAVx5 users to install custom certificates (e.g., self-signed, internal CA) that the app will trust.

### Architecture

```kotlin
class CustomCertManager(context: Context) {
    private val keyStore: KeyStore

    fun addCertificate(cert: X509Certificate) {
        // Add cert to app-private store
    }

    fun removeCertificate(alias: String) {
        // Remove from store
    }

    fun getTrustManager(): X509TrustManager {
        // Return custom TrustManager
    }
}

// Usage with HTTP client
val trustManager = customCertManager.getTrustManager()
val sslContext = SSLContext.getInstance("TLS")
sslContext.init(null, arrayOf(trustManager), null)

val client = OkHttpClient.Builder()
    .sslSocketFactory(sslContext.socketFactory, trustManager)
    .build()
```

### Lessons for SwiftXDAV

**iOS/macOS Equivalent:**
- Use `URLSessionDelegate` with `urlSession(_:didReceive:completionHandler:)`
- Implement custom certificate validation
- Store trusted certificates in Keychain

```swift
class CertificateTrustManager: NSObject, URLSessionDelegate {
    private var trustedCertificates: Set<SecCertificate> = []

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check if certificate is in our trusted set
        if isTrusted(serverTrust) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func isTrusted(_ serverTrust: SecTrust) -> Bool {
        // Validate against our custom trusted certificates
    }
}
```

---

## synctools

**Repository:** https://github.com/bitfireAT/synctools (referenced from DAVx5)
**Language:** Kotlin
**Purpose:** iCalendar/vCard/Tasks processing and Android content provider access

### Key Features

- Bridge between iCal4j/ez-vcard and Android content providers
- Conversion between iCalendar and Android Calendar Provider
- Conversion between vCard and Android Contacts Provider
- Task provider integration

### Architecture

```kotlin
// Calendar event conversion
class AndroidEvent {
    companion object {
        fun fromICalendar(event: VEvent): ContentValues {
            // Convert iCal4j VEvent to Android Calendar Provider format
        }

        fun toICalendar(values: ContentValues): VEvent {
            // Convert Android Calendar Provider to iCal4j VEvent
        }
    }
}

// Contact conversion
class AndroidContact {
    companion object {
        fun fromVCard(vcard: VCard): List<ContentProviderOperation> {
            // Convert ez-vcard VCard to Android Contacts Provider ops
        }

        fun toVCard(contactId: Long): VCard {
            // Convert Android Contacts Provider to ez-vcard VCard
        }
    }
}
```

### Lessons for SwiftXDAV

**iOS/macOS Equivalent:**
- EventKit framework for calendar integration
- Contacts framework for contact integration
- Create similar conversion layers

```swift
// EventKit bridge
extension EKEvent {
    convenience init(from vevent: VEvent) {
        // Convert VEvent to EKEvent
    }

    func toVEvent() -> VEvent {
        // Convert EKEvent to VEvent
    }
}

// Contacts bridge
extension CNContact {
    convenience init(from vcard: VCard) {
        // Convert VCard to CNContact
    }

    func toVCard() -> VCard {
        // Convert CNContact to VCard
    }
}
```

---

## Python CalDAV Libraries

### Radicale

**Repository:** https://github.com/Kozea/Radicale
**Language:** Python
**License:** GPLv3
**Type:** Server implementation

### Overview

Radicale is a lightweight CalDAV/CardDAV server, useful for understanding server-side behavior.

**Key Features:**
- Simple file-based storage
- Extensible with plugins
- Full CalDAV/CardDAV compliance

**Lessons:**
- Study server-side validation logic
- Understand expected client behavior
- Use for integration testing

### caldav Python Library

**Documentation:** https://caldav.readthedocs.io/
**Language:** Python
**License:** Various open-source

**Key Features:**
- CalDAV client library
- Simple, high-level API
- Supports most CalDAV servers

**Example:**
```python
from caldav import DAVClient

client = DAVClient(url="https://caldav.example.com", username="user", password="pass")
principal = client.principal()

calendars = principal.calendars()
for calendar in calendars:
    print(f"Calendar: {calendar.name}")

    events = calendar.events()
    for event in events:
        print(f"Event: {event.data}")
```

**Lessons for SwiftXDAV:**
- High-level API design
- Discovery flow (principal → calendars → events)
- Simple, Pythonic interface can inspire Swift's protocol-oriented design

---

## Key Takeaways

### Architecture Patterns

1. **Modular Design**
   - Separate network, parsing, and business logic
   - SwiftXDAV should follow: Core → Network → Calendar/Contacts

2. **Protocol-Oriented**
   - Define protocols for HTTP client, parsers, storage
   - Enable testing with mock implementations

3. **Property System**
   - Factory pattern for extensibility
   - Type-safe accessors
   - Support for custom properties

4. **Resource-Oriented API**
   - Wrap URL + HTTP client in resource object
   - Provides clean interface for operations

### Parsing Strategies

1. **Streaming Parsers**
   - Memory efficient
   - Swift: Use `XMLParser` (SAX-style) or implement custom streaming

2. **Error Tolerance**
   - Parse non-compliant data when possible
   - Collect warnings for debugging
   - Validate separately from parsing

3. **Version Handling**
   - Auto-detect format version
   - Support multiple versions (vCard 3.0/4.0, iCalendar 2.0)

### Sync Strategies

1. **Efficient Delta Sync**
   - Use sync-tokens when available
   - Fallback to ETag comparison
   - Batch operations with multiget

2. **Conflict Resolution**
   - Track local modifications
   - Detect conflicts (both sides modified)
   - Strategy: server wins, client wins, or user decides

3. **State Management**
   - Store ETags, sync tokens
   - Track modification times
   - Per-resource sync status

### Network Patterns

1. **Service Discovery**
   - .well-known URLs
   - DNS SRV records
   - PROPFIND for capabilities

2. **Retry Logic**
   - Exponential backoff
   - Respect rate limiting
   - Handle transient errors

3. **Batch Operations**
   - Use multiget REPORT
   - Reduce round trips
   - Better performance

### Swift Implementation Recommendations

**Use These Libraries:**
- **Alamofire**: HTTP networking (supports custom methods)
- **XMLCoder** or native `XMLParser`: XML parsing
- Native Swift types for data models

**Create These Modules:**
1. **SwiftXDAVCore**: Base types, protocols, utilities
2. **SwiftXDAVNetwork**: HTTP, WebDAV, authentication
3. **SwiftXDAVCalendar**: CalDAV, iCalendar parsing
4. **SwiftXDAVContacts**: CardDAV, vCard parsing
5. **SwiftXDAVSync**: Synchronization logic (optional)

**Adopt These Patterns:**
- Actor-based concurrency for thread safety
- Async/await for asynchronous operations
- Protocol-oriented design for flexibility
- Value types (structs) for data models
- Comprehensive error types

**Test Strategy:**
- Unit tests for parsers and utilities
- Mock HTTP client for network tests
- Integration tests against real servers (iCloud, Google)
- Test fixtures from RFCs and real-world examples

---

## Conclusion

The existing CalDAV/CardDAV ecosystem provides excellent reference implementations. Key lessons:

1. **Modular architecture** enables reuse and testing
2. **Streaming parsers** are memory-efficient
3. **Property factories** enable extensibility
4. **Resource-oriented APIs** provide clean interfaces
5. **Comprehensive error handling** improves reliability
6. **Efficient sync** requires tokens, ETags, and batching

SwiftXDAV should learn from these implementations while leveraging Swift's modern features: strong typing, async/await, actors, and protocol-oriented programming.
