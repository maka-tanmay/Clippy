import Foundation

enum PasteTransform: String, CaseIterable, Identifiable {
  case uppercase, lowercase, trimmed, normalizedWhitespace, strippedTracking, prettyJSON

  var id: String { rawValue }

  var title: String {
    switch self {
    case .uppercase: NSLocalizedString("paste_transform_uppercase", comment: "")
    case .lowercase: NSLocalizedString("paste_transform_lowercase", comment: "")
    case .trimmed: NSLocalizedString("paste_transform_trimmed", comment: "")
    case .normalizedWhitespace: NSLocalizedString("paste_transform_normalized_whitespace", comment: "")
    case .strippedTracking: NSLocalizedString("paste_transform_stripped_tracking", comment: "")
    case .prettyJSON: NSLocalizedString("paste_transform_pretty_json", comment: "")
    }
  }

  func apply(_ string: String) -> String {
    switch self {
    case .uppercase: string.uppercased()
    case .lowercase: string.lowercased()
    case .trimmed: string.trimmingCharacters(in: .whitespacesAndNewlines)
    case .normalizedWhitespace: Self.normalizeWhitespace(string)
    case .strippedTracking: Self.stripTracking(string)
    case .prettyJSON: Self.prettyPrintJSON(string)
    }
  }

  // Collapse every run of whitespace (spaces, tabs, newlines) to a single
  // space and trim the ends — handy for text pasted out of PDFs or wrapped code.
  private static func normalizeWhitespace(_ string: String) -> String {
    string
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private static let trackingParams: Set<String> = [
    "fbclid", "gclid", "dclid", "msclkid", "mc_eid", "igshid", "twclid", "li_fat_id", "yclid"
  ]

  private static func stripTracking(_ string: String) -> String {
    guard var components = URLComponents(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
          components.scheme != nil,
          let items = components.queryItems, !items.isEmpty else {
      return string
    }

    let kept = items.filter { item in
      let name = item.name.lowercased()
      return !name.hasPrefix("utm_") && !trackingParams.contains(name)
    }
    components.queryItems = kept.isEmpty ? nil : kept
    return components.url?.absoluteString ?? string
  }

  private static func prettyPrintJSON(_ string: String) -> String {
    guard let data = string.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
          let result = String(data: pretty, encoding: .utf8) else {
      return string
    }
    return result
  }
}
