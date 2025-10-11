# RFC Standards Documentation

This document provides comprehensive documentation of all RFC standards relevant to the SwiftXDAV framework implementation.

## Table of Contents

1. [RFC 4918 - WebDAV](#rfc-4918-webdav)
2. [RFC 4791 - CalDAV](#rfc-4791-caldav)
3. [RFC 6352 - CardDAV](#rfc-6352-carddav)
4. [RFC 5545 - iCalendar](#rfc-5545-icalendar)
5. [RFC 6350 - vCard](#rfc-6350-vcard)
6. [RFC 6638 - CalDAV Scheduling Extensions](#rfc-6638-caldav-scheduling)
7. [Additional Related RFCs](#additional-related-rfcs)

---

## RFC 4918 - WebDAV

**Title:** HTTP Extensions for Web Distributed Authoring and Versioning (WebDAV)
**Published:** June 2007
**Status:** Standards Track
**Obsoletes:** RFC 2518
**Official URL:** https://datatracker.ietf.org/doc/html/rfc4918

### Overview

Web Distributed Authoring and Versioning (WebDAV) consists of a set of methods, headers, and content-types ancillary to HTTP/1.1 for the management of resource properties, creation and management of resource collections, URL namespace manipulation, and resource locking (collision avoidance).

### Core Concepts

WebDAV extends HTTP/1.1 to support remote web content authoring by providing:

1. **Property Management**: Name/value pairs describing resource state
2. **Collection Management**: Creating and managing document collections (like directories)
3. **Resource Locking**: Preventing simultaneous editing conflicts
4. **Namespace Manipulation**: Moving and copying resources

### Key HTTP Methods

#### PROPFIND
Retrieves properties defined on resources.

**Features:**
- Supports depth levels: 0 (resource only), 1 (resource + immediate children), or infinity (entire tree)
- Can request: specific properties, all properties, or property names only
- Returns 207 Multi-Status response with property values

**Request Headers:**
- `Depth: 0|1|infinity`

#### PROPPATCH
Updates resource properties (both live and dead properties).

**Features:**
- Atomic operation - all property updates succeed or fail together
- Returns 207 Multi-Status response

#### MKCOL
Creates a new collection (directory-like container).

**Features:**
- Creates a collection at the specified URL
- Parent collection must already exist
- Returns 201 Created on success

#### COPY
Copies a resource from one URI to another.

**Features:**
- Does not duplicate existing write locks
- Can overwrite destination if `Overwrite: T` header is set
- Supports `Depth` header for collections

**Request Headers:**
- `Destination: <uri>` (required)
- `Overwrite: T|F` (optional, default is T)
- `Depth: 0|infinity` (for collections)

#### MOVE
Moves a resource from one URI to another.

**Features:**
- Equivalent to COPY followed by DELETE
- Preserves live properties
- Lock tokens move with the resource

**Request Headers:**
- `Destination: <uri>` (required)
- `Overwrite: T|F` (optional)

#### LOCK
Applies a write lock to prevent simultaneous editing.

**Lock Types:**
- **Exclusive locks**: Only one principal can hold the lock
- **Shared locks**: Multiple principals can hold locks simultaneously

**Features:**
- Prevents "lost update" problem
- Lock tokens identify specific locks
- Supports timeout and refresh mechanisms
- Can lock collections recursively

**Request Headers:**
- `Timeout: Second-xxx` (optional, server determines actual timeout)

**Request Body:**
```xml
<?xml version="1.0" encoding="utf-8" ?>
<D:lockinfo xmlns:D='DAV:'>
  <D:lockscope><D:exclusive/></D:lockscope>
  <D:locktype><D:write/></D:locktype>
  <D:owner>
    <D:href>mailto:user@example.com</D:href>
  </D:owner>
</D:lockinfo>
```

#### UNLOCK
Removes an existing lock from a resource.

**Request Headers:**
- `Lock-Token: <opaquelocktoken:xxx>` (required)

### Property Model

Properties are name/value pairs providing metadata about resources.

**Two Types:**

1. **Live Properties**:
   - Enforced and managed by server
   - Have specific semantics (e.g., `getcontentlength`, `creationdate`)
   - Server ensures consistency

2. **Dead Properties**:
   - Arbitrary properties set by clients
   - No special semantics
   - Server stores and returns verbatim

**Common Live Properties:**
- `DAV:creationdate` - When resource was created
- `DAV:displayname` - Human-readable name
- `DAV:getcontentlength` - Size in bytes
- `DAV:getcontenttype` - MIME type
- `DAV:getetag` - Entity tag for cache validation
- `DAV:getlastmodified` - Last modification date
- `DAV:resourcetype` - Type of resource (collection, etc.)
- `DAV:lockdiscovery` - Active locks on resource
- `DAV:supportedlock` - Lock types supported

### Status Codes

WebDAV introduces several new HTTP status codes:

- **207 Multi-Status**: Response contains multiple independent status codes
- **422 Unprocessable Entity**: Request was well-formed but contains semantic errors
- **423 Locked**: Resource is currently locked
- **424 Failed Dependency**: Request failed due to failure of a previous request
- **507 Insufficient Storage**: Server cannot store representation needed to complete request

### XML Namespaces

WebDAV uses XML extensively. The primary namespace is:
- `xmlns:D="DAV:"`

### Implementation Requirements for Swift

1. **HTTP Client**: Need robust HTTP/1.1 client with support for custom methods (use Alamofire)
2. **XML Parser**: Need to parse and generate WebDAV XML (use XMLCoder or native XMLParser)
3. **Property System**: Need to model live and dead properties
4. **Lock Management**: Need to track lock tokens and handle timeouts
5. **Collection Handling**: Need to represent hierarchical resource structures
6. **Error Handling**: Need to parse and handle 207 Multi-Status responses

---

## RFC 4791 - CalDAV

**Title:** Calendaring Extensions to WebDAV (CalDAV)
**Published:** March 2007
**Status:** Standards Track
**Authors:** C. Daboo (Apple), B. Desruisseaux (Oracle), L. Dusseault (CommerceNet)
**Official URL:** https://datatracker.ietf.org/doc/html/rfc4791

### Overview

CalDAV defines extensions to WebDAV to specify a standard way of accessing, managing, and sharing calendaring and scheduling information based on the iCalendar format. This document defines the "calendar-access" feature of CalDAV.

### Core Concepts

CalDAV builds on WebDAV by adding:

1. **Calendar Collections**: Special WebDAV collections that contain calendar data
2. **Calendar Object Resources**: Individual iCalendar objects within collections
3. **Calendar Queries**: Advanced querying of calendar data with time ranges and filters
4. **Scheduling Support**: Managing attendees, free/busy, and scheduling operations

### Calendar Collections

Calendar collections are WebDAV collections with special properties and behaviors.

**Required Properties:**
- Must report both `DAV:collection` and `CALDAV:calendar` in resourcetype
- `CALDAV:calendar-description` - Human-readable description
- `CALDAV:calendar-timezone` - Default timezone for collection
- `CALDAV:supported-calendar-component-set` - Which component types are allowed (VEVENT, VTODO, etc.)
- `CALDAV:supported-calendar-data` - Supported media types and versions

**Collection Restrictions:**
- Can only contain calendar object resources and non-calendar collections
- All calendar object resources in a collection must have unique UIDs
- Calendar collections cannot be nested within each other

### Calendar Object Resources

Individual calendar items stored in calendar collections.

**Key Requirements:**
- Must contain only one type of calendar component (VEVENT, VTODO, VJOURNAL, or VFREEBUSY)
  - Exception: VTIMEZONE components can co-exist with other components
- Must have a unique UID within the collection
- Can represent recurring events and all their exceptions in a single resource
- Must use iCalendar format (RFC 5545)

**Supported Media Types:**
- `text/calendar` with version 2.0

### REPORT Method

CalDAV introduces extensive use of the WebDAV REPORT method for querying.

#### CALDAV:calendar-query REPORT

Allows complex searches of calendar data with filtering.

**Key Features:**
- Time range filtering (events within date range)
- Component filtering (only VEVENT, only VTODO, etc.)
- Property filtering (events with specific properties)
- Partial retrieval (return only specific properties)
- Expand recurring events within a time range
- Limit results to a specific time range

**Example Request:**
```xml
<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <D:getetag/>
    <C:calendar-data>
      <C:comp name="VCALENDAR">
        <C:comp name="VEVENT">
          <C:prop name="SUMMARY"/>
          <C:prop name="DTSTART"/>
          <C:prop name="DTEND"/>
        </C:comp>
      </C:comp>
    </C:calendar-data>
  </D:prop>
  <C:filter>
    <C:comp-filter name="VCALENDAR">
      <C:comp-filter name="VEVENT">
        <C:time-range start="20250101T000000Z" end="20250201T000000Z"/>
      </C:comp-filter>
    </C:comp-filter>
  </C:filter>
</C:calendar-query>
```

#### CALDAV:calendar-multiget REPORT

Retrieves specific calendar resources by their URLs.

**Purpose:** Efficiently fetch multiple calendar objects in a single request

**Example Request:**
```xml
<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-multiget xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <D:getetag/>
    <C:calendar-data/>
  </D:prop>
  <D:href>/calendars/user/home/event1.ics</D:href>
  <D:href>/calendars/user/home/event2.ics</D:href>
</C:calendar-multiget>
```

#### CALDAV:free-busy-query REPORT

Retrieves free/busy information for a user within a time range.

**Purpose:** Check availability without seeing full event details

### Access Control

CalDAV introduces new WebDAV ACL privileges:

- **CALDAV:read-free-busy**: Read free/busy time information only
  - Allows checking availability without seeing event details
  - Can be granted independently of read access

### Calendar Data Operations

#### Creating a Calendar Object

1. Generate unique UID for the calendar object
2. PUT the iCalendar data to a new resource URL
3. Set `Content-Type: text/calendar; charset=utf-8`
4. Server validates iCalendar data and returns 201 Created

#### Updating a Calendar Object

1. GET the current resource with its ETag
2. Modify the iCalendar data
3. PUT back with `If-Match` header containing ETag
4. Server validates and updates, returns 204 No Content or new ETag

#### Deleting a Calendar Object

1. Send DELETE request to resource URL
2. Server returns 204 No Content on success

### CalDAV Discovery

Clients discover CalDAV support through:

1. **OPTIONS request**: Server returns `DAV: calendar-access` in header
2. **PROPFIND on principal**: Discover user's calendar home
   - `CALDAV:calendar-home-set` property points to user's calendars
3. **PROPFIND on calendar home**: Discover individual calendars
   - Look for collections with `CALDAV:calendar` in resourcetype

### Implementation Requirements for Swift

1. **iCalendar Parser**: Need full RFC 5545 parser/generator (consider porting iCal4j or libical patterns)
2. **Query Builder**: Need to construct complex XML queries for REPORT method
3. **Time Range Calculations**: Need robust date/time and recurrence handling
4. **UID Management**: Need to ensure unique UIDs and handle UID-based lookups
5. **ETag Handling**: Need to track ETags for optimistic concurrency control
6. **Timezone Support**: Need comprehensive timezone database and conversions

---

## RFC 6352 - CardDAV

**Title:** CardDAV: vCard Extensions to Web Distributed Authoring and Versioning (WebDAV)
**Published:** August 2011
**Status:** Standards Track
**Author:** C. Daboo (Apple)
**Official URL:** https://datatracker.ietf.org/doc/html/rfc6352

### Overview

CardDAV extends WebDAV to provide a standard way of accessing, managing, and sharing contact information based on the vCard format.

### Core Concepts

CardDAV builds on WebDAV by adding:

1. **Address Book Collections**: Special WebDAV collections containing contact data
2. **Address Object Resources**: Individual vCard objects within collections
3. **Address Book Queries**: Advanced querying and searching of contacts
4. **Synchronization**: Efficient syncing of contact data

### Address Book Collections

Address book collections are WebDAV collections specifically for storing contact information.

**Required Properties:**
- Must report both `DAV:collection` and `CARDDAV:addressbook` in resourcetype
- `CARDDAV:addressbook-description` - Human-readable description
- `CARDDAV:supported-address-data` - Supported vCard versions and media types
- `CARDDAV:max-resource-size` - Maximum size in octets of address resources

**Collection Restrictions:**
- Can only contain address object resources and non-addressbook collections
- Address book collections cannot be nested within each other

### Address Object Resources

Individual contact cards stored in address book collections.

**Key Requirements:**
- Must contain one and only one vCard
- Must use vCard format (RFC 6350)
- UID property in vCard should be used for resource identification
- Must support vCard version 3.0 (version 4.0 support is optional but recommended)

**Supported Media Types:**
- `text/vcard` (vCard 3.0 and 4.0)
- Servers MUST support vCard v3 as minimum

### REPORT Method

#### CARDDAV:addressbook-query REPORT

Searches address books using filters.

**Features:**
- Text matching on vCard properties
- Property filtering
- Partial retrieval of vCard data
- Limit result count

**Example Request:**
```xml
<?xml version="1.0" encoding="utf-8" ?>
<C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">
  <D:prop>
    <D:getetag/>
    <C:address-data>
      <C:prop name="FN"/>
      <C:prop name="EMAIL"/>
    </C:address-data>
  </D:prop>
  <C:filter>
    <C:prop-filter name="FN">
      <C:text-match collation="i;unicode-casemap" match-type="contains">John</C:text-match>
    </C:prop-filter>
  </C:filter>
</C:addressbook-query>
```

#### CARDDAV:addressbook-multiget REPORT

Retrieves specific address resources by their URLs.

**Purpose:** Efficiently fetch multiple vCards in a single request

**Example Request:**
```xml
<?xml version="1.0" encoding="utf-8" ?>
<C:addressbook-multiget xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">
  <D:prop>
    <D:getetag/>
    <C:address-data/>
  </D:prop>
  <D:href>/addressbooks/user/contacts/contact1.vcf</D:href>
  <D:href>/addressbooks/user/contacts/contact2.vcf</D:href>
</C:addressbook-multiget>
```

### Search and Filtering

CardDAV provides powerful text matching capabilities:

**Collation Support:**
- `i;ascii-casemap` - ASCII case-insensitive
- `i;octet` - Exact byte match
- `i;unicode-casemap` - Unicode case-insensitive

**Match Types:**
- `equals` - Exact match
- `contains` - Substring match
- `starts-with` - Prefix match
- `ends-with` - Suffix match

### Address Book Discovery

Clients discover CardDAV support through:

1. **OPTIONS request**: Server returns `DAV: addressbook` in header
2. **PROPFIND on principal**: Discover user's address book home
   - `CARDDAV:addressbook-home-set` property points to user's address books
3. **PROPFIND on address book home**: Discover individual address books
   - Look for collections with `CARDDAV:addressbook` in resourcetype

### Synchronization

CardDAV supports efficient synchronization using:

1. **ETags**: Track version of each address resource
2. **Sync-Token**: Track state of entire collection
3. **WebDAV Sync (RFC 6578)**: Efficient delta syncs

**Sync Collection Report:**
```xml
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-token>http://example.com/sync/1234</D:sync-token>
  <D:prop>
    <D:getetag/>
  </D:prop>
</D:sync-collection>
```

### Security Requirements

Servers MUST:
- Support TLS for transport security
- Implement WebDAV Access Control (RFC 3744)
- Support ETags for optimistic concurrency control

### Implementation Requirements for Swift

1. **vCard Parser**: Need full RFC 6350 parser/generator (consider porting ez-vcard patterns)
2. **Query Builder**: Need to construct CardDAV XML queries
3. **Text Matching**: Need to implement collation and match type algorithms
4. **Sync Support**: Need to track sync tokens and ETags
5. **Discovery**: Need to implement principal and home set discovery
6. **Batch Operations**: Need to support multiget for efficient fetching

---

## RFC 5545 - iCalendar

**Title:** Internet Calendaring and Scheduling Core Object Specification (iCalendar)
**Published:** September 2009
**Status:** Standards Track
**Obsoletes:** RFC 2445
**Official URL:** https://datatracker.ietf.org/doc/html/rfc5545

### Overview

iCalendar defines a data format for representing and exchanging calendaring and scheduling information such as events, to-dos, journal entries, and free/busy information.

### Core Components

#### VCALENDAR
Top-level container component. Every iCalendar object must have exactly one VCALENDAR component.

**Required Properties:**
- `VERSION`: Must be "2.0"
- `PRODID`: Product identifier (e.g., "-//Company//Product//EN")
- At least one calendar component (VEVENT, VTODO, VJOURNAL, VFREEBUSY, or VTIMEZONE)

#### VEVENT
Represents a calendar event (meeting, appointment, etc.).

**Required Properties:**
- `UID`: Globally unique identifier
- `DTSTAMP`: Date/time stamp of object creation

**Common Properties:**
- `DTSTART`: Event start date/time
- `DTEND` or `DURATION`: Event end time or duration
- `SUMMARY`: Short description/title
- `DESCRIPTION`: Full description
- `LOCATION`: Where event takes place
- `STATUS`: Event status (TENTATIVE, CONFIRMED, CANCELLED)
- `ORGANIZER`: Event organizer
- `ATTENDEE`: Event participant(s)
- `RRULE`: Recurrence rule
- `EXDATE`: Exception dates (dates to exclude from recurrence)
- `RDATE`: Additional occurrence dates

#### VTODO
Represents a to-do item or task.

**Required Properties:**
- `UID`: Globally unique identifier
- `DTSTAMP`: Date/time stamp

**Common Properties:**
- `SUMMARY`: Short description
- `DTSTART`: Start date/time
- `DUE`: Due date/time
- `COMPLETED`: Completion date/time
- `PERCENT-COMPLETE`: Percentage complete (0-100)
- `STATUS`: Task status (NEEDS-ACTION, COMPLETED, IN-PROCESS, CANCELLED)
- `PRIORITY`: Priority level (0-9, with 0 undefined and 1 highest)

#### VJOURNAL
Represents a journal entry or note.

**Required Properties:**
- `UID`: Globally unique identifier
- `DTSTAMP`: Date/time stamp

**Common Properties:**
- `SUMMARY`: Short description
- `DESCRIPTION`: Full journal text
- `DTSTART`: Date/time associated with entry

#### VFREEBUSY
Represents free or busy time information.

**Required Properties:**
- `UID`: Globally unique identifier
- `DTSTAMP`: Date/time stamp

**Common Properties:**
- `DTSTART`: Start of free/busy time range
- `DTEND`: End of free/busy time range
- `FREEBUSY`: Free or busy periods with type (FREE, BUSY, BUSY-UNAVAILABLE, BUSY-TENTATIVE)

#### VTIMEZONE
Represents timezone information.

**Required Properties:**
- `TZID`: Timezone identifier

**Sub-components:**
- `STANDARD`: Standard time rules
- `DAYLIGHT`: Daylight saving time rules

### Time Representation

iCalendar supports three date-time formats:

1. **Local Time (Floating)**
   - Format: `20250611T090000`
   - No timezone information
   - Interpreted in local timezone

2. **UTC Time**
   - Format: `20250611T090000Z`
   - Ends with 'Z' suffix
   - Universal coordinated time

3. **Local Time with Timezone Reference**
   - Format: `TZID=America/New_York:20250611T090000`
   - References VTIMEZONE component in calendar
   - Explicit timezone context

**Date-Only Format:**
- Format: `20250611`
- No time component
- Represents entire day

### Recurrence Rules (RRULE)

Recurrence rules define repeating events with powerful pattern matching.

**Basic Structure:**
```
RRULE:FREQ=<frequency>;[additional rules]
```

**Frequency Types:**
- `SECONDLY`: Repeats every N seconds
- `MINUTELY`: Repeats every N minutes
- `HOURLY`: Repeats every N hours
- `DAILY`: Repeats every N days
- `WEEKLY`: Repeats every N weeks
- `MONTHLY`: Repeats every N months
- `YEARLY`: Repeats every N years

**End Conditions:**
- `UNTIL=<date-time>`: Repeat until this date/time
- `COUNT=<integer>`: Repeat this many times
- If neither specified: repeats forever

**Additional Rules:**
- `INTERVAL=<n>`: Repeat every n intervals (default: 1)
- `BYSECOND`: List of seconds (0-60)
- `BYMINUTE`: List of minutes (0-59)
- `BYHOUR`: List of hours (0-23)
- `BYDAY`: List of weekdays (MO, TU, WE, TH, FR, SA, SU)
  - Can have prefix for nth occurrence: `-1SU` (last Sunday), `2FR` (second Friday)
- `BYMONTHDAY`: List of month days (1-31, -1 to -31)
- `BYYEARDAY`: List of year days (1-366, -1 to -366)
- `BYWEEKNO`: List of week numbers (1-53, -1 to -53)
- `BYMONTH`: List of months (1-12)
- `BYSETPOS`: Select specific occurrences from a set
- `WKST`: Start of work week (default: MO)

**Examples:**

Every day:
```
RRULE:FREQ=DAILY
```

Every Tuesday and Thursday:
```
RRULE:FREQ=WEEKLY;BYDAY=TU,TH
```

Monthly on the 2nd and 15th:
```
RRULE:FREQ=MONTHLY;BYMONTHDAY=2,15
```

Last Friday of every month:
```
RRULE:FREQ=MONTHLY;BYDAY=-1FR
```

Every weekday (Monday-Friday):
```
RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR
```

First Monday of every quarter:
```
RRULE:FREQ=MONTHLY;INTERVAL=3;BYDAY=1MO
```

10 occurrences, every other day:
```
RRULE:FREQ=DAILY;INTERVAL=2;COUNT=10
```

Every day until December 31, 2025:
```
RRULE:FREQ=DAILY;UNTIL=20251231T235959Z
```

### Key Properties

#### Descriptive Properties
- `SUMMARY`: Short title/summary
- `DESCRIPTION`: Full description
- `LOCATION`: Physical location
- `CATEGORIES`: Comma-separated categories/tags
- `CLASS`: Access classification (PUBLIC, PRIVATE, CONFIDENTIAL)
- `COMMENT`: Additional comments

#### Date/Time Properties
- `DTSTART`: Start date/time
- `DTEND`: End date/time
- `DURATION`: Duration (alternative to DTEND)
- `DTSTAMP`: Creation/modification timestamp
- `CREATED`: Creation date
- `LAST-MODIFIED`: Last modification date

#### Relationship Properties
- `ATTENDEE`: Participant in event
  - Parameters: CN (name), ROLE (chair/req-participant/opt-participant), PARTSTAT (participation status), RSVP (yes/no)
- `ORGANIZER`: Event organizer
  - Parameters: CN (name), SENT-BY (on behalf of)
- `RELATED-TO`: Related calendar objects (by UID)
- `URL`: Associated URL

#### Scheduling Properties
- `STATUS`: Status of calendar object
  - VEVENT: TENTATIVE, CONFIRMED, CANCELLED
  - VTODO: NEEDS-ACTION, COMPLETED, IN-PROCESS, CANCELLED
  - VJOURNAL: DRAFT, FINAL, CANCELLED
- `TRANSP`: Time transparency (OPAQUE - blocks time, TRANSPARENT - doesn't block)
- `SEQUENCE`: Revision number (incremented on updates)

#### Alarm Properties
See VALARM component below.

### VALARM Component

Represents alarms/reminders within events or todos.

**Action Types:**
- `AUDIO`: Play a sound
- `DISPLAY`: Display a message
- `EMAIL`: Send an email

**Trigger:**
- `TRIGGER`: When alarm fires
  - Relative: `-PT15M` (15 minutes before), `PT0S` (at event time)
  - Absolute: Specific date/time

**Example - Display alarm 15 minutes before:**
```
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:Reminder
TRIGGER:-PT15M
END:VALARM
```

**Example - Email alarm:**
```
BEGIN:VALARM
ACTION:EMAIL
SUMMARY:Reminder
DESCRIPTION:Event starting soon
ATTENDEE:mailto:user@example.com
TRIGGER:-PT1H
END:VALARM
```

### Encoding and Character Sets

- **Default Character Set**: UTF-8
- **Line Folding**: Lines should not exceed 75 octets, fold with CRLF + space
- **Escaping**:
  - `\n` for newline
  - `\\` for backslash
  - `\;` for semicolon
  - `\,` for comma in value list

**Example with line folding:**
```
DESCRIPTION:This is a long description that exceeds seventy-five character
 s and must be folded onto multiple lines.
```

### Parameters

Properties can have parameters that modify their meaning:

**Common Parameters:**
- `VALUE`: Value type (DATE, DATE-TIME, DURATION, TEXT, etc.)
- `TZID`: Timezone identifier
- `LANGUAGE`: Language tag (en-US, fr-FR, etc.)
- `CN`: Common name (human-readable name)
- `ALTREP`: Alternate text representation (URL)
- `ENCODING`: Encoding type (BASE64 for binary)
- `FMTTYPE`: MIME media type

**Example:**
```
ORGANIZER;CN="John Doe":mailto:john@example.com
ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;CN="Jane Smith":mailto:jane@example.com
```

### Implementation Requirements for Swift

1. **Parser/Lexer**: Need to parse iCalendar text format with proper line folding and escaping
2. **Component Model**: Need Swift types for VEVENT, VTODO, VJOURNAL, VFREEBUSY, VTIMEZONE
3. **Property Model**: Need Swift types for all iCalendar properties with parameters
4. **Recurrence Engine**: Need to calculate occurrence dates from RRULE (complex!)
5. **Timezone Support**: Need VTIMEZONE parser and integration with system timezones
6. **Date/Time Handling**: Need robust date/time parsing and formatting (ISO 8601)
7. **Validation**: Need to validate required properties and component relationships
8. **Serialization**: Need to generate valid iCalendar text from Swift objects

---

## RFC 6350 - vCard

**Title:** vCard Format Specification
**Published:** August 2011
**Status:** Standards Track
**Obsoletes:** RFC 2425, 2426, 4770
**Official URL:** https://datatracker.ietf.org/doc/html/rfc6350

### Overview

vCard defines a data format for representing and exchanging contact information such as names, addresses, telephone numbers, email addresses, URLs, and more.

### Core Structure

Every vCard must:
1. Begin with `BEGIN:VCARD`
2. Include `VERSION:4.0` (or 3.0 for older format)
3. Include `FN` (Formatted Name) property
4. End with `END:VCARD`

**Basic Example:**
```
BEGIN:VCARD
VERSION:4.0
FN:John Doe
N:Doe;John;Q.;Dr.;Jr.
EMAIL:john.doe@example.com
TEL;TYPE=work:+1-555-555-5555
END:VCARD
```

### Charset and Encoding

- **Character Set**: UTF-8 exclusively (no other encodings allowed)
- **Line Folding**: Maximum 75 octets per line, fold with CRLF + space/tab
- **Escaping Rules**:
  - `\n` or `\N` for newline
  - `\\` for backslash
  - `\;` for semicolon
  - `\,` for comma

### Key Properties

#### Identification Properties

**FN** (Formatted Name) - REQUIRED
- Human-readable full name
- Example: `FN:John Q. Public, Esq.`

**N** (Name)
- Structured name components
- Format: Family;Given;Additional;Prefix;Suffix
- Example: `N:Doe;John;Michael;Dr.;Jr.`

**NICKNAME**
- One or more nicknames
- Example: `NICKNAME:Johnny`

**PHOTO**
- Photograph or avatar
- Can be inline data or URI
- Example: `PHOTO:http://example.com/photo.jpg`
- Example (inline): `PHOTO:data:image/jpeg;base64,/9j/4AAQ...`

**BDAY** (Birthday)
- Birth date
- Example: `BDAY:19850415`
- Example: `BDAY:1985-04-15`

**ANNIVERSARY**
- Wedding anniversary or similar
- Example: `ANNIVERSARY:20100621`

**GENDER**
- Gender identity
- Example: `GENDER:M` (male), `GENDER:F` (female), `GENDER:O` (other), `GENDER:N` (none/not applicable)

#### Communication Properties

**TEL** (Telephone)
- Phone number
- Parameters: TYPE (work, home, cell, voice, fax, pager, etc.)
- Example: `TEL;TYPE=work,voice:+1-555-555-1234`
- Example: `TEL;TYPE=home:+1-555-555-5678`

**EMAIL**
- Email address
- Parameters: TYPE (work, home), PREF (preference order)
- Example: `EMAIL;TYPE=work:john@example.com`
- Example: `EMAIL;TYPE=home;PREF=1:john@home.com`

**IMPP** (Instant Messaging)
- Instant messaging and presence protocol address
- Example: `IMPP:xmpp:john@jabber.org`
- Example: `IMPP:aim:johndoe123`

**LANG** (Language)
- Preferred languages
- Example: `LANG;PREF=1:en-US`
- Example: `LANG:fr-CA`

#### Delivery Address Properties

**ADR** (Address)
- Structured delivery address
- Format: PO Box;Extended;Street;Locality;Region;Postal Code;Country
- Parameters: TYPE (work, home)
- Example:
```
ADR;TYPE=work:;;123 Main St;Springfield;IL;62701;USA
```

Full example with all components:
```
ADR;TYPE=home:PO Box 123;;456 Oak Ave;Anytown;CA;90210;USA
```

#### Organizational Properties

**TITLE**
- Job title or position
- Example: `TITLE:Senior Software Engineer`

**ROLE**
- Organizational role or function
- Example: `ROLE:Team Lead`

**LOGO**
- Organization logo
- Similar to PHOTO
- Example: `LOGO:http://example.com/logo.png`

**ORG** (Organization)
- Organization name and units
- Example: `ORG:ABC Corporation;Marketing Department`

**MEMBER**
- Member of a group (for vCards representing groups)
- Example: `MEMBER:urn:uuid:03a0e51f-d1aa-4385-8a53-e29025acd8af`

**RELATED**
- Related person
- Parameters: TYPE (spouse, child, parent, sibling, friend, etc.)
- Example: `RELATED;TYPE=spouse:Jane Doe`

#### Geographical Properties

**TZ** (Timezone)
- Timezone
- Example: `TZ:America/New_York`
- Example: `TZ:-0500`

**GEO** (Geographic Position)
- Geographic coordinates (latitude/longitude)
- Format: geo URI
- Example: `GEO:geo:37.386013,-122.082932`

#### URL Properties

**URL**
- Web page or online resource
- Example: `URL:http://example.com`
- Example: `URL;TYPE=work:https://company.example.com/~john`

**SOURCE**
- Source of directory information
- Example: `SOURCE:ldap://ldap.example.com/cn=John%20Doe`

#### Security Properties

**KEY**
- Public key or authentication certificate
- Example: `KEY:http://example.com/keys/john.pgp`
- Example (inline): `KEY:data:application/pgp-keys;base64,MIICajCCA...`

#### Calendar Properties

**FBURL** (Free/Busy URL)
- URL to person's free/busy information
- Example: `FBURL:http://example.com/fb/john.ifb`

**CALADRURI** (Calendar Address URI)
- Calendar user address
- Example: `CALADRURI:mailto:john@example.com`

**CALURI** (Calendar URI)
- URL to person's calendar
- Example: `CALURI:http://example.com/cal/john`

#### Metadata Properties

**UID** (Unique Identifier)
- Globally unique identifier for the vCard
- Example: `UID:urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1`

**REV** (Revision)
- Last modified timestamp
- Example: `REV:20230615T120000Z`

**CATEGORIES**
- Application-specific categories or tags
- Example: `CATEGORIES:Family,Friends`

**NOTE**
- Supplementary notes or comments
- Example: `NOTE:Met at conference in 2023`

**PRODID** (Product Identifier)
- Identifier for the product that created the vCard
- Example: `PRODID:-//Example Corp//Contact Manager 1.0//EN`

**CLIENTPIDMAP**
- Maps client PIDs to URIs
- Used for synchronization

**XML**
- Extended XML-encoded vCard data
- Allows embedding of arbitrary XML

### Value Types

vCard supports multiple data types:

- **text**: Plain text (default for many properties)
- **uri**: URI reference
- **date**: Date (YYYYMMDD or YYYY-MM-DD)
- **time**: Time (HHMMSS or HH:MM:SS)
- **date-time**: Date and time combined
- **date-and-or-time**: Date, time, or both
- **timestamp**: Complete date-time with timezone
- **boolean**: TRUE or FALSE
- **integer**: Signed integer
- **float**: Floating point number
- **utc-offset**: UTC offset (e.g., -0500)
- **language-tag**: RFC 5646 language tag
- **iana-token**: IANA-registered type

### Parameters

Properties can have parameters:

**TYPE**
- Type or category of property
- Common values: work, home, voice, fax, cell, video, pager, textphone
- Example: `TEL;TYPE=work,voice:+1-555-5555`

**PREF** (Preference)
- Preference order (1-100, 1 being most preferred)
- Example: `EMAIL;PREF=1:primary@example.com`

**LANGUAGE**
- Language tag for property value
- Example: `ADR;LANGUAGE=fr:;;123 rue Main;Paris;;75001;France`

**VALUE**
- Specifies value type explicitly
- Example: `BDAY;VALUE=text:circa 1800`

**ALTID** (Alternative ID)
- Groups alternative representations of the same property
- Example:
```
FN;ALTID=1;LANGUAGE=en:John Doe
FN;ALTID=1;LANGUAGE=fr:Jean Dupont
```

**MEDIATYPE**
- MIME media type for property
- Example: `PHOTO;MEDIATYPE=image/png:http://example.com/photo.png`

**CALSCALE**
- Calendar scale (typically "gregorian")
- Example: `BDAY;CALSCALE=gregorian:19850415`

### Multi-Valued Properties

Some properties can have multiple values:

- Separate with comma: `CATEGORIES:Work,Development,OpenSource`
- Multiple instances: Multiple EMAIL properties

### Groups

Properties can be grouped with a prefix:

```
item1.EMAIL:john@work.com
item1.X-ABLabel:Work Email
item2.EMAIL:john@home.com
item2.X-ABLabel:Home Email
```

### Version Differences

**vCard 3.0 vs 4.0:**

- v3.0 supports multiple character sets; v4.0 is UTF-8 only
- v3.0 uses TYPE parameter differently for some properties
- v4.0 adds new properties: KIND, GENDER, LANG, ANNIVERSARY, CALURI, FBURL
- v4.0 has different encoding for structured values
- Many servers still primarily support v3.0

### Implementation Requirements for Swift

1. **Parser/Lexer**: Need to parse vCard text format with line folding and escaping
2. **Property Model**: Need Swift types for all vCard properties
3. **Value Types**: Need Swift representations for all vCard value types
4. **Parameter Support**: Need to parse and generate property parameters
5. **Version Support**: Need to support both vCard 3.0 and 4.0
6. **Encoding**: Need proper UTF-8 and BASE64 handling
7. **Validation**: Need to validate required properties (VERSION, FN)
8. **Multi-value Handling**: Need to parse comma-separated and multiple properties
9. **Grouping**: Need to support property grouping
10. **Serialization**: Need to generate valid vCard text from Swift objects

---

## RFC 6638 - CalDAV Scheduling Extensions

**Title:** Scheduling Extensions to CalDAV
**Published:** June 2012
**Status:** Standards Track
**Authors:** C. Daboo (Apple), B. Desruisseaux (Oracle)
**Updates:** RFC 4791, RFC 5546
**Official URL:** https://datatracker.ietf.org/doc/html/rfc6638

### Overview

RFC 6638 defines extensions to CalDAV to specify a standard way of performing scheduling operations with iCalendar-based calendar components. This document defines the "calendar-auto-schedule" feature of CalDAV.

### Core Concepts

Scheduling extensions add:

1. **Scheduling Inbox and Outbox Collections**: Special collections for managing scheduling messages
2. **Automatic Scheduling**: Server processes scheduling messages automatically
3. **Free/Busy Management**: Improved free/busy query mechanisms
4. **Attendee Management**: Standardized attendee invitation and response handling

### Scheduling Collections

#### Scheduling Outbox Collection

Used to submit scheduling messages to other users.

**Properties:**
- `CALDAV:schedule-outbox-URL`: URL of user's scheduling outbox
- Clients POST scheduling messages here
- Server processes and delivers to recipients

**Usage:**
1. Client creates iTIP (iCalendar Transport-Independent Interoperability Protocol) message
2. Client POSTs to scheduling outbox
3. Server validates and delivers to attendees
4. Server returns delivery status

#### Scheduling Inbox Collection

Receives scheduling messages from other users.

**Properties:**
- `CALDAV:schedule-inbox-URL`: URL of user's scheduling inbox
- Server delivers incoming scheduling messages here
- Messages can be automatically processed or require manual action

**Processing:**
- Server can auto-process: automatically update calendar based on replies
- User can manually review messages before accepting

### Scheduling Operations

#### Sending Invitations

1. Organizer creates VEVENT with ATTENDEE properties
2. Organizer PUTs event to their calendar
3. Server automatically generates iTIP REQUEST messages
4. Server delivers to each attendee's inbox
5. Attendees receive notification

**Alternative Method:**
1. Organizer creates iTIP REQUEST message
2. Organizer POSTs to scheduling outbox
3. Server validates and delivers

#### Responding to Invitations

Attendee receives invitation and can:
- ACCEPT: Will attend
- DECLINE: Will not attend
- TENTATIVE: Might attend
- DELEGATE: Delegate to another person

**Process:**
1. Attendee receives REQUEST in inbox
2. Attendee updates PARTSTAT parameter on their copy
3. Server generates iTIP REPLY message
4. Server sends REPLY to organizer's inbox
5. Organizer's calendar automatically updates

#### Updating Events

When organizer updates event:
1. Organizer updates event in their calendar
2. Server detects change affecting attendees
3. Server generates iTIP REQUEST with updated details
4. Server delivers to attendees
5. Attendees' calendars automatically update

#### Canceling Events

1. Organizer deletes event or sets STATUS:CANCELLED
2. Server generates iTIP CANCEL messages
3. Server delivers to all attendees
4. Attendees' calendars automatically remove/cancel event

### Free/Busy Management

Improved free/busy handling with automatic scheduling.

**CALDAV:schedule-default-calendar-URL Property:**
- Indicates which calendar should be checked for free/busy by default

**Free/Busy Query:**
```xml
<C:free-busy-query xmlns:C="urn:ietf:params:xml:ns:caldav">
  <C:time-range start="20250611T000000Z" end="20250615T000000Z"/>
</C:free-busy-query>
```

POST to another user's scheduling outbox to get their free/busy.

### Capabilities Discovery

Servers indicate scheduling support via:

**OPTIONS Response:**
```
DAV: 1, 2, 3, calendar-access, calendar-auto-schedule
```

**Properties:**
- `CALDAV:calendar-user-address-set`: User's calendar addresses
- `CALDAV:schedule-inbox-URL`: Inbox URL
- `CALDAV:schedule-outbox-URL`: Outbox URL
- `CALDAV:schedule-default-calendar-URL`: Default calendar for new events

### iTIP Methods

Based on RFC 5546, the iCalendar Transport-Independent Interoperability Protocol.

**Key Methods:**
- **REQUEST**: Invitation or update from organizer
- **REPLY**: Response from attendee
- **CANCEL**: Cancellation from organizer
- **ADD**: Add instances to recurring event
- **REFRESH**: Request for latest version
- **COUNTER**: Counter-proposal from attendee
- **DECLINECOUNTER**: Rejection of counter-proposal

### Attendee Properties

**ATTENDEE Property Parameters:**
- `CN`: Common name (display name)
- `CUTYPE`: Calendar user type (INDIVIDUAL, GROUP, RESOURCE, ROOM, UNKNOWN)
- `DELEGATED-FROM`: Who delegated to this attendee
- `DELEGATED-TO`: Who this attendee delegated to
- `DIR`: Directory entry for attendee
- `LANGUAGE`: Language preference
- `MEMBER`: Group membership
- `PARTSTAT`: Participation status
  - NEEDS-ACTION: No response yet
  - ACCEPTED: Accepted invitation
  - DECLINED: Declined invitation
  - TENTATIVE: Tentatively accepted
  - DELEGATED: Delegated to another person
- `ROLE`: Role in event
  - CHAIR: Chairperson
  - REQ-PARTICIPANT: Required participant
  - OPT-PARTICIPANT: Optional participant
  - NON-PARTICIPANT: Information only
- `RSVP`: RSVP requested (TRUE/FALSE)
- `SENT-BY`: Sent on behalf of

**Example:**
```
ATTENDEE;CN="Jane Doe";CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;
 PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:jane@example.com
```

### Organizer Property

**ORGANIZER Property Parameters:**
- `CN`: Common name
- `DIR`: Directory entry
- `LANGUAGE`: Language preference
- `SENT-BY`: Sent on behalf of

**Example:**
```
ORGANIZER;CN="John Smith":mailto:john@example.com
```

### Scheduling Privileges

New WebDAV ACL privileges:

- `CALDAV:schedule-deliver`: Deliver scheduling messages to inbox
- `CALDAV:schedule-deliver-invite`: Deliver invitations
- `CALDAV:schedule-deliver-reply`: Deliver replies
- `CALDAV:schedule-query-freebusy`: Query free/busy information
- `CALDAV:schedule-send`: Send scheduling messages via outbox
- `CALDAV:schedule-send-invite`: Send invitations
- `CALDAV:schedule-send-reply`: Send replies
- `CALDAV:schedule-send-freebusy`: Send free/busy information

### Implementation Requirements for Swift

1. **iTIP Support**: Need to generate and parse iTIP messages (RFC 5546)
2. **Inbox/Outbox**: Need to manage scheduling inbox and outbox collections
3. **Automatic Processing**: Need to automatically update events based on scheduling messages
4. **Attendee Management**: Need to track attendee status and generate appropriate responses
5. **Free/Busy**: Need to calculate and publish free/busy information
6. **Delegation**: Need to support attendee delegation
7. **Notifications**: Need to notify users of new scheduling messages
8. **Conflict Detection**: Need to detect scheduling conflicts

---

## Additional Related RFCs

### RFC 3744 - WebDAV Access Control Protocol (ACL)

**Official URL:** https://datatracker.ietf.org/doc/html/rfc3744

Defines access control extensions for WebDAV, including:
- Principals (users, groups)
- Access control lists
- Privileges (read, write, etc.)
- Inheritance

Used extensively by CalDAV and CardDAV for access control.

### RFC 5546 - iCalendar Transport-Independent Interoperability Protocol (iTIP)

**Official URL:** https://datatracker.ietf.org/doc/html/rfc5546

Defines how to use iCalendar objects for scheduling:
- Methods: REQUEST, REPLY, CANCEL, etc.
- Attendee workflows
- Organizer workflows
- Status tracking

Required for implementing CalDAV scheduling (RFC 6638).

### RFC 6578 - Collection Synchronization for WebDAV

**Official URL:** https://datatracker.ietf.org/doc/html/rfc6578

Defines efficient synchronization mechanism:
- Sync tokens
- Delta synchronization
- Detecting additions, modifications, deletions

Essential for efficient CalDAV/CardDAV sync.

### RFC 7809 - CalDAV Time Zones by Reference

**Official URL:** https://datatracker.ietf.org/doc/html/rfc7809

Updates RFC 4791 to allow:
- Referencing timezone by ID instead of embedding full VTIMEZONE
- Reduces data transfer size
- Simplifies timezone updates

### RFC 7986 - New Properties for iCalendar

**Official URL:** https://datatracker.ietf.org/doc/html/rfc7986

Adds new iCalendar properties:
- COLOR: Event/calendar color
- IMAGE: Event image
- CONFERENCE: Conference system URL
- NAME: Calendar name
- DESCRIPTION: Calendar description
- REFRESH-INTERVAL: Suggested refresh interval
- SOURCE: URL to source calendar

### RFC 4918 Extensions

Several RFCs extend the core WebDAV specification:
- RFC 3253: Versioning Extensions
- RFC 3648: Ordered Collections
- RFC 3744: Access Control Protocol
- RFC 4437: Redirect Reference Resources
- RFC 5323: WebDAV SEARCH
- RFC 5842: Binding Extensions

---

## Implementation Roadmap

### Phase 1: Core Protocols (Essential)
1. HTTP client with custom method support
2. WebDAV (RFC 4918): PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK
3. XML parsing and generation for WebDAV

### Phase 2: Data Formats (Essential)
1. iCalendar (RFC 5545): Full parser and generator
2. vCard (RFC 6350): Full parser and generator for v3.0 and v4.0
3. Recurrence rule engine for RRULE
4. Timezone support (VTIMEZONE + system integration)

### Phase 3: CalDAV (Essential)
1. CalDAV (RFC 4791): Calendar collections, calendar queries, REPORT method
2. Calendar discovery and capability detection
3. Event CRUD operations
4. Recurrence handling and expansion

### Phase 4: CardDAV (Essential)
1. CardDAV (RFC 6352): Address book collections, queries, REPORT method
2. Contact discovery
3. Contact CRUD operations
4. Search and filtering

### Phase 5: Synchronization (Important)
1. ETag handling for optimistic concurrency
2. Collection synchronization (RFC 6578)
3. Efficient delta sync
4. Conflict resolution

### Phase 6: Scheduling (Important)
1. CalDAV scheduling extensions (RFC 6638)
2. iTIP support (RFC 5546)
3. Inbox/Outbox collections
4. Attendee management
5. Free/busy queries

### Phase 7: Advanced Features (Nice to Have)
1. Access control (RFC 3744)
2. Timezone by reference (RFC 7809)
3. Extended iCalendar properties (RFC 7986)
4. Calendar sharing
5. Delegation

---

## Summary

The SwiftXDAV framework must implement:

**Core Standards:**
- RFC 4918 (WebDAV) - Foundation for all DAV protocols
- RFC 4791 (CalDAV) - Calendar access and management
- RFC 6352 (CardDAV) - Contact access and management
- RFC 5545 (iCalendar) - Calendar data format
- RFC 6350 (vCard) - Contact data format

**Essential Extensions:**
- RFC 6638 (CalDAV Scheduling) - Meeting invitations and responses
- RFC 5546 (iTIP) - Calendar interoperability protocol
- RFC 6578 (WebDAV Sync) - Efficient synchronization

**Supporting Standards:**
- RFC 3744 (WebDAV ACL) - Access control
- RFC 7809 (Timezone by Reference) - Efficient timezone handling
- RFC 7986 (iCalendar Extensions) - Modern calendar features

This comprehensive standards foundation will enable SwiftXDAV to interoperate with all major CalDAV/CardDAV servers including iCloud, Google Calendar/Contacts, and others.
