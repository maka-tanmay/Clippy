import Defaults
import XCTest
@testable import Maccy

class PrivacyGuardTests: XCTestCase {
  override func setUp() {
    super.setUp()
    Defaults[.expireRegexps] = []
    Defaults[.expireAfterMinutes] = 10
    Defaults[.detectSecrets] = true
  }

  func testDetectsSecrets() {
    for secret in [
      "AKIAIOSFODNN7EXAMPLE",
      "-----BEGIN RSA PRIVATE KEY-----\nabc",
      "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U",
      "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef1234",
      "sk-proj-abcdefghijklmnopqrstuvwxyz123456",
      "xoxb-1234567890-abcdefghij"
    ] {
      let expiration = PrivacyGuard.expiration(for: "token: \(secret)")
      XCTAssertNotNil(expiration, secret)
      XCTAssertTrue(expiration?.isSecret ?? false, secret)
    }
  }

  func testIgnoresOrdinaryText() {
    XCTAssertNil(PrivacyGuard.expiration(for: "meet me at 5pm, bring the AKIA report"))
    XCTAssertNil(PrivacyGuard.expiration(for: "https://example.com/page?id=42"))
    XCTAssertNil(PrivacyGuard.expiration(for: nil))
  }

  func testSecretsCanBeDisabled() {
    Defaults[.detectSecrets] = false
    XCTAssertNil(PrivacyGuard.expiration(for: "AKIAIOSFODNN7EXAMPLE"))
  }

  func testUserRules() {
    Defaults[.expireRegexps] = ["^\\d{6}$"]
    Defaults[.expireAfterMinutes] = 1

    let expiration = PrivacyGuard.expiration(for: "483920")
    XCTAssertNotNil(expiration)
    XCTAssertFalse(expiration?.isSecret ?? true)
    if let date = expiration?.date {
      XCTAssertEqual(date.timeIntervalSinceNow, 60, accuracy: 5)
    }

    XCTAssertNil(PrivacyGuard.expiration(for: "not an otp 483920 inline"))
  }
}
