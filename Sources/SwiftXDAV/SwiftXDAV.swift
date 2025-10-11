/// SwiftXDAV - A modern Swift framework for CalDAV/CardDAV/WebDAV integration
///
/// This is the umbrella module that re-exports all public APIs from the framework modules.
///
/// ## Overview
///
/// SwiftXDAV provides a complete implementation of CalDAV (RFC 4791), CardDAV (RFC 6352),
/// and WebDAV (RFC 4918) protocols for Apple platforms. It includes parsers for iCalendar
/// (RFC 5545) and vCard (RFC 6350) formats.
///
/// ## Topics
///
/// ### Getting Started
/// - ``CalDAVClient``
/// - ``CardDAVClient``
///
/// ### Core Types
/// - ``SwiftXDAVCore``
///
/// ### Network Layer
/// - ``SwiftXDAVNetwork``
///
/// ### Calendar Support
/// - ``SwiftXDAVCalendar``
///
/// ### Contacts Support
/// - ``SwiftXDAVContacts``

@_exported import SwiftXDAVCore
@_exported import SwiftXDAVNetwork
@_exported import SwiftXDAVCalendar
@_exported import SwiftXDAVContacts
