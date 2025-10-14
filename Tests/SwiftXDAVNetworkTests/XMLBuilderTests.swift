import XCTest
@testable import SwiftXDAVNetwork

final class XMLBuilderTests: XCTestCase {

    // MARK: - Basic Building Tests

    func testBuildEmptyDocument() {
        var xml = XMLBuilder()
        let result = xml.build()

        XCTAssertTrue(result.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
    }

    func testStartDocument() {
        var xml = XMLBuilder()
        xml.startDocument()

        let result = xml.build()
        XCTAssertTrue(result.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
    }

    func testStartDocumentOnlyOnce() {
        var xml = XMLBuilder()
        xml.startDocument()
        xml.startDocument() // Should be ignored

        let result = xml.build()
        let occurrences = result.components(separatedBy: "<?xml").count - 1
        XCTAssertEqual(occurrences, 1, "XML declaration should appear only once")
    }

    // MARK: - Element Tests

    func testStartAndEndElement() {
        var xml = XMLBuilder()
        xml.startElement("root")
        xml.endElement("root")

        let result = xml.build()
        XCTAssertTrue(result.contains("<root>"))
        XCTAssertTrue(result.contains("</root>"))
    }

    func testElementWithAttributes() {
        var xml = XMLBuilder()
        xml.startElement("d:propfind", attributes: ["xmlns:d": "DAV:"])
        xml.endElement("d:propfind")

        let result = xml.build()
        XCTAssertTrue(result.contains("<d:propfind"))
        XCTAssertTrue(result.contains("xmlns:d=\"DAV:\""))
        XCTAssertTrue(result.contains("</d:propfind>"))
    }

    func testElementWithMultipleAttributes() {
        var xml = XMLBuilder()
        xml.startElement("element", attributes: [
            "attr1": "value1",
            "attr2": "value2",
            "attr3": "value3"
        ])
        xml.endElement("element")

        let result = xml.build()
        XCTAssertTrue(result.contains("attr1=\"value1\""))
        XCTAssertTrue(result.contains("attr2=\"value2\""))
        XCTAssertTrue(result.contains("attr3=\"value3\""))
    }

    // MARK: - Self-Closing Element Tests

    func testEmptyElement() {
        var xml = XMLBuilder()
        xml.element("d:displayname")

        let result = xml.build()
        XCTAssertTrue(result.contains("<d:displayname/>"))
    }

    func testElementWithValue() {
        var xml = XMLBuilder()
        xml.element("d:displayname", value: "My Calendar")

        let result = xml.build()
        XCTAssertTrue(result.contains("<d:displayname>My Calendar</d:displayname>"))
    }

    func testElementWithEmptyValue() {
        var xml = XMLBuilder()
        xml.element("d:displayname", value: "")

        let result = xml.build()
        XCTAssertTrue(result.contains("<d:displayname/>"))
    }

    func testElementWithValueAndAttributes() {
        var xml = XMLBuilder()
        xml.element("item", value: "test", attributes: ["id": "123"])

        let result = xml.build()
        XCTAssertTrue(result.contains("id=\"123\""))
        XCTAssertTrue(result.contains(">test</item>"))
    }

    // MARK: - XML Escaping Tests

    func testXMLEscaping() {
        let input = "< > & \" '"
        let escaped = input.xmlEscaped

        XCTAssertEqual(escaped, "&lt; &gt; &amp; &quot; &apos;")
    }

    func testXMLEscapingInElementValue() {
        var xml = XMLBuilder()
        xml.element("description", value: "<script>alert('XSS')</script>")

        let result = xml.build()
        XCTAssertTrue(result.contains("&lt;script&gt;"))
        XCTAssertTrue(result.contains("&apos;XSS&apos;"))
        XCTAssertFalse(result.contains("<script>"))
    }

    func testXMLEscapingInAttributes() {
        var xml = XMLBuilder()
        xml.element("element", attributes: ["value": "\"quoted\" & <special>"])

        let result = xml.build()
        XCTAssertTrue(result.contains("&quot;quoted&quot;"))
        XCTAssertTrue(result.contains("&amp;"))
        XCTAssertTrue(result.contains("&lt;special&gt;"))
    }

    func testXMLUnescaping() {
        let input = "&lt; &gt; &amp; &quot; &apos;"
        let unescaped = input.xmlUnescaped

        XCTAssertEqual(unescaped, "< > & \" '")
    }

    func testXMLUnescapingOrder() {
        // Ensure &amp; is unescaped last to avoid double-unescaping
        let input = "&amp;lt;"
        let unescaped = input.xmlUnescaped

        XCTAssertEqual(unescaped, "&lt;")
    }

    // MARK: - Nested Elements Tests

    func testNestedElements() {
        var xml = XMLBuilder()
        xml.startElement("root")
        xml.startElement("child")
        xml.element("grandchild", value: "value")
        xml.endElement("child")
        xml.endElement("root")

        let result = xml.build()
        XCTAssertTrue(result.contains("<root><child><grandchild>value</grandchild></child></root>"))
    }

    func testPropfindExample() {
        var xml = XMLBuilder()
        xml.startElement("d:propfind", attributes: ["xmlns:d": "DAV:"])
        xml.startElement("d:prop")
        xml.element("d:displayname")
        xml.element("d:resourcetype")
        xml.element("d:getetag")
        xml.endElement("d:prop")
        xml.endElement("d:propfind")

        let result = xml.build()

        XCTAssertTrue(result.contains("<d:propfind"))
        XCTAssertTrue(result.contains("xmlns:d=\"DAV:\""))
        XCTAssertTrue(result.contains("<d:prop>"))
        XCTAssertTrue(result.contains("<d:displayname/>"))
        XCTAssertTrue(result.contains("<d:resourcetype/>"))
        XCTAssertTrue(result.contains("<d:getetag/>"))
        XCTAssertTrue(result.contains("</d:prop>"))
        XCTAssertTrue(result.contains("</d:propfind>"))
    }

    // MARK: - Raw XML Tests

    func testRawXML() {
        var xml = XMLBuilder()
        xml.startElement("root")
        xml.raw("<custom>unescaped</custom>")
        xml.endElement("root")

        let result = xml.build()
        XCTAssertTrue(result.contains("<custom>unescaped</custom>"))
    }

    // MARK: - Build Data Tests

    func testBuildData() {
        var xml = XMLBuilder()
        xml.element("root", value: "test")

        let data = xml.buildData()
        let string = String(data: data, encoding: .utf8)

        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("<root>test</root>"))
    }

    func testBuildDataWithUTF8() {
        var xml = XMLBuilder()
        xml.element("text", value: "Hello 世界 🌍")

        let data = xml.buildData()
        let string = String(data: data, encoding: .utf8)

        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("Hello 世界 🌍"))
    }

    // MARK: - Attribute Ordering Tests

    func testAttributeOrdering() {
        var xml = XMLBuilder()
        xml.startElement("element", attributes: [
            "zebra": "z",
            "apple": "a",
            "middle": "m"
        ])
        xml.endElement("element")

        let result = xml.build()

        // Attributes should be sorted alphabetically
        let appleIndex = result.range(of: "apple=")
        let middleIndex = result.range(of: "middle=")
        let zebraIndex = result.range(of: "zebra=")

        XCTAssertNotNil(appleIndex)
        XCTAssertNotNil(middleIndex)
        XCTAssertNotNil(zebraIndex)

        XCTAssertLessThan(appleIndex!.lowerBound, middleIndex!.lowerBound)
        XCTAssertLessThan(middleIndex!.lowerBound, zebraIndex!.lowerBound)
    }

    // MARK: - Special Characters Tests

    func testUnicodeCharacters() {
        var xml = XMLBuilder()
        xml.element("text", value: "日本語 العربية Ελληνικά")

        let result = xml.build()
        XCTAssertTrue(result.contains("日本語 العربية Ελληνικά"))
    }

    func testEmojis() {
        var xml = XMLBuilder()
        xml.element("text", value: "😀 🎉 🚀")

        let result = xml.build()
        XCTAssertTrue(result.contains("😀 🎉 🚀"))
    }

    // MARK: - Complex Document Test

    func testComplexDocument() {
        var xml = XMLBuilder()

        xml.startElement("d:multistatus", attributes: ["xmlns:d": "DAV:"])
        xml.startElement("d:response")
        xml.element("d:href", value: "/calendars/user/calendar/")
        xml.startElement("d:propstat")
        xml.startElement("d:prop")
        xml.element("d:displayname", value: "My Calendar")
        xml.element("d:resourcetype")
        xml.endElement("d:prop")
        xml.element("d:status", value: "HTTP/1.1 200 OK")
        xml.endElement("d:propstat")
        xml.endElement("d:response")
        xml.endElement("d:multistatus")

        let result = xml.build()

        XCTAssertTrue(result.contains("<?xml"))
        XCTAssertTrue(result.contains("<d:multistatus"))
        XCTAssertTrue(result.contains("<d:response>"))
        XCTAssertTrue(result.contains("<d:href>/calendars/user/calendar/</d:href>"))
        XCTAssertTrue(result.contains("<d:displayname>My Calendar</d:displayname>"))
        XCTAssertTrue(result.contains("HTTP/1.1 200 OK"))
        XCTAssertTrue(result.contains("</d:multistatus>"))
    }
}
