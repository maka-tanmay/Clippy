import XCTest
@testable import Maccy

class ItemTagTests: XCTestCase {
  func testParse() {
    XCTAssertEqual(ItemTag.parse(query: "tag:work invoice").0, "work")
    XCTAssertEqual(ItemTag.parse(query: "tag:work invoice").1, "invoice")
    XCTAssertEqual(ItemTag.parse(query: "invoice tag:Work").0, "Work")
    XCTAssertEqual(ItemTag.parse(query: "invoice tag:Work").1, "invoice")
    XCTAssertNil(ItemTag.parse(query: "no tags here").0)
    XCTAssertEqual(ItemTag.parse(query: "no tags here").1, "no tags here")
  }

  func testNormalize() {
    XCTAssertEqual(ItemTag.normalize("  work , Invoice ,work,, "), ["work", "Invoice"])
    XCTAssertEqual(ItemTag.normalize(""), [])
  }
}
