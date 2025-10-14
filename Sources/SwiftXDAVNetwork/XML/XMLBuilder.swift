import Foundation

/// Utility for building XML documents
///
/// `XMLBuilder` provides a safe and convenient way to construct XML documents
/// for WebDAV requests such as PROPFIND, PROPPATCH, and REPORT.
///
/// ## Usage
///
/// ```swift
/// var xml = XMLBuilder()
/// xml.startDocument()
/// xml.startElement("d:propfind", attributes: ["xmlns:d": "DAV:"])
/// xml.startElement("d:prop")
/// xml.element("d:displayname")
/// xml.element("d:resourcetype")
/// xml.endElement("d:prop")
/// xml.endElement("d:propfind")
///
/// let xmlString = xml.build()
/// ```
///
/// ## Topics
///
/// ### Building XML
/// - ``startDocument()``
/// - ``startElement(_:attributes:)``
/// - ``endElement(_:)``
/// - ``element(_:value:attributes:)``
/// - ``build()``
public struct XMLBuilder {
    private var elements: [String] = []
    private var hasDeclaration = false

    /// Initialize a new XML builder
    public init() {}

    /// Add XML declaration
    ///
    /// Adds the standard XML declaration: `<?xml version="1.0" encoding="UTF-8"?>`
    ///
    /// This is automatically included when you call ``build()`` unless you've
    /// already called this method explicitly.
    public mutating func startDocument() {
        if !hasDeclaration {
            elements.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
            hasDeclaration = true
        }
    }

    /// Start an XML element
    ///
    /// - Parameters:
    ///   - name: The element name (e.g., "d:propfind")
    ///   - attributes: Optional attributes as key-value pairs
    ///
    /// ## Example
    ///
    /// ```swift
    /// xml.startElement("d:propfind", attributes: ["xmlns:d": "DAV:"])
    /// ```
    public mutating func startElement(_ name: String, attributes: [String: String] = [:]) {
        var element = "<\(name)"

        // Add attributes in sorted order for consistent output
        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            element += " \(key)=\"\(value.xmlEscaped)\""
        }

        element += ">"
        elements.append(element)
    }

    /// End an XML element
    ///
    /// - Parameter name: The element name to close
    ///
    /// ## Example
    ///
    /// ```swift
    /// xml.endElement("d:propfind")
    /// ```
    public mutating func endElement(_ name: String) {
        elements.append("</\(name)>")
    }

    /// Add a complete element with optional value and attributes
    ///
    /// This is a convenience method that combines ``startElement(_:attributes:)``,
    /// content, and ``endElement(_:)`` into a single call.
    ///
    /// - Parameters:
    ///   - name: The element name
    ///   - value: Optional text content for the element
    ///   - attributes: Optional attributes
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Empty element
    /// xml.element("d:displayname")
    ///
    /// // Element with value
    /// xml.element("d:displayname", value: "My Calendar")
    ///
    /// // Element with attributes
    /// xml.element("d:href", value: "/path", attributes: ["type": "calendar"])
    /// ```
    public mutating func element(_ name: String, value: String? = nil, attributes: [String: String] = [:]) {
        if let value = value, !value.isEmpty {
            // Element with content
            var element = "<\(name)"

            for (key, val) in attributes.sorted(by: { $0.key < $1.key }) {
                element += " \(key)=\"\(val.xmlEscaped)\""
            }

            element += ">\(value.xmlEscaped)</\(name)>"
            elements.append(element)
        } else {
            // Empty element (self-closing or empty tags)
            var element = "<\(name)"

            for (key, val) in attributes.sorted(by: { $0.key < $1.key }) {
                element += " \(key)=\"\(val.xmlEscaped)\""
            }

            element += "/>"
            elements.append(element)
        }
    }

    /// Add raw XML content
    ///
    /// Use this to insert pre-formatted XML or text content that should not be escaped.
    ///
    /// - Parameter xml: The raw XML string to append
    ///
    /// ## Warning
    ///
    /// The content is not validated or escaped. Ensure it's valid XML.
    public mutating func raw(_ xml: String) {
        elements.append(xml)
    }

    /// Build the final XML document
    ///
    /// - Returns: The complete XML document as a string
    ///
    /// If ``startDocument()`` hasn't been called, this automatically adds
    /// the XML declaration at the beginning.
    public mutating func build() -> String {
        if !hasDeclaration {
            startDocument()
        }
        return elements.joined()
    }

    /// Build and return as Data
    ///
    /// - Returns: The XML document as UTF-8 encoded data
    /// - Throws: Never throws (UTF-8 encoding always succeeds for valid strings)
    public mutating func buildData() -> Data {
        let xmlString = build()
        return xmlString.data(using: .utf8) ?? Data()
    }
}

// MARK: - String Extensions

extension String {
    /// Escape XML special characters
    ///
    /// Replaces the five predefined XML entities:
    /// - `&` → `&amp;`
    /// - `<` → `&lt;`
    /// - `>` → `&gt;`
    /// - `"` → `&quot;`
    /// - `'` → `&apos;`
    ///
    /// - Returns: The XML-escaped string
    var xmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    /// Unescape XML entities
    ///
    /// Converts XML entities back to their original characters:
    /// - `&amp;` → `&`
    /// - `&lt;` → `<`
    /// - `&gt;` → `>`
    /// - `&quot;` → `"`
    /// - `&apos;` → `'`
    ///
    /// - Returns: The unescaped string
    var xmlUnescaped: String {
        self
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")  // Must be last!
    }
}
