import Defaults
import Foundation

// Decides whether a newly copied item should self-destruct.
// User rules (regex + TTL) run first; the built-in secret patterns catch
// credentials and expire them fast.
enum PrivacyGuard {
  static let secretExpiry: TimeInterval = 120

  // ponytail: high-signal literal shapes only, no entropy heuristic — false
  // positives erode trust faster than a missed hit; extend the list if needed.
  private static let secretPatterns: [NSRegularExpression] = [
    "AKIA[0-9A-Z]{16}",                                                    // AWS access key id
    "-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY",
    "eyJ[A-Za-z0-9_-]{10,}\\.eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}", // JWT
    "gh[pousr]_[A-Za-z0-9]{36,}",                                          // GitHub token
    "sk-[A-Za-z0-9_-]{20,}",                                               // sk-style API key
    "xox[baprs]-[A-Za-z0-9-]{10,}"                                         // Slack token
  ].compactMap { try? NSRegularExpression(pattern: $0) }

  struct Expiration {
    let date: Date
    let isSecret: Bool
  }

  static func expiration(for text: String?) -> Expiration? {
    guard let text, !text.isEmpty else { return nil }

    let range = NSRange(text.startIndex..., in: text)

    for pattern in Defaults[.expireRegexps] {
      if let regex = try? NSRegularExpression(pattern: pattern),
         regex.firstMatch(in: text, range: range) != nil {
        let ttl = TimeInterval(Defaults[.expireAfterMinutes] * 60)
        return Expiration(date: Date.now.addingTimeInterval(ttl), isSecret: false)
      }
    }

    if Defaults[.detectSecrets] {
      for regex in secretPatterns where regex.firstMatch(in: text, range: range) != nil {
        return Expiration(date: Date.now.addingTimeInterval(secretExpiry), isSecret: true)
      }
    }

    return nil
  }
}
