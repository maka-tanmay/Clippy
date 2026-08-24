import XCTest
@testable import Maccy

class PasteTransformTests: XCTestCase {
  func testCase() {
    XCTAssertEqual(PasteTransform.uppercase.apply("Hello wörld"), "HELLO WÖRLD")
    XCTAssertEqual(PasteTransform.lowercase.apply("Hello WÖRLD"), "hello wörld")
  }

  func testTrimmed() {
    XCTAssertEqual(PasteTransform.trimmed.apply("  hi there\n\n"), "hi there")
  }

  func testStripTracking() {
    XCTAssertEqual(
      PasteTransform.strippedTracking.apply("https://ex.com/p?id=1&utm_source=x&fbclid=abc&gclid=1"),
      "https://ex.com/p?id=1"
    )
    // All params tracking → query dropped entirely
    XCTAssertEqual(
      PasteTransform.strippedTracking.apply("https://ex.com/p?utm_campaign=x"),
      "https://ex.com/p"
    )
    // Non-URL text is untouched
    XCTAssertEqual(PasteTransform.strippedTracking.apply("not a url utm_source=x"), "not a url utm_source=x")
  }

  func testPrettyJSON() {
    XCTAssertEqual(
      PasteTransform.prettyJSON.apply(#"{"b":1,"a":[2]}"#),
      "{\n  \"a\" : [\n    2\n  ],\n  \"b\" : 1\n}"
    )
    // Invalid JSON is untouched
    XCTAssertEqual(PasteTransform.prettyJSON.apply("{nope"), "{nope")
  }

  func testNormalizeWhitespace() {
    XCTAssertEqual(PasteTransform.normalizedWhitespace.apply("  a\t b\n\nc  "), "a b c")
    XCTAssertEqual(PasteTransform.normalizedWhitespace.apply("single"), "single")
  }
}
