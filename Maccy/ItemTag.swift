import AppKit
import SwiftData

// Lightweight tagging: items carry `tags: [String]`, editable from the context
// menu and filterable in search with `tag:work`.
enum ItemTag {
  // Splits a "tag:foo rest" token out of a query, anywhere in the string.
  // Returns (tag, remaining query). Case-insensitive on the "tag:" prefix.
  static func parse(query: String) -> (String?, String) {
    guard let range = query.range(of: #"(?i)\btag:(\S+)"#, options: .regularExpression) else {
      return (nil, query)
    }
    let token = query[range].dropFirst(4) // drop "tag:"
    var remaining = query
    remaining.removeSubrange(range)
    remaining = remaining.trimmingCharacters(in: .whitespaces)
    return (String(token), remaining)
  }

  // Turns a comma-separated string into cleaned, de-duplicated tags.
  static func normalize(_ raw: String) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for piece in raw.split(separator: ",") {
      let tag = piece.trimmingCharacters(in: .whitespacesAndNewlines)
      let key = tag.lowercased()
      if !tag.isEmpty, !seen.contains(key) {
        seen.insert(key)
        result.append(tag)
      }
    }
    return result
  }

  @MainActor
  static func edit(_ item: HistoryItem) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("tags_edit_title", comment: "")
    alert.informativeText = NSLocalizedString("tags_edit_message", comment: "")
    alert.addButton(withTitle: NSLocalizedString("tags_edit_save", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("tags_edit_cancel", comment: ""))

    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    field.stringValue = item.tags.joined(separator: ", ")
    field.placeholderString = NSLocalizedString("tags_edit_placeholder", comment: "")
    alert.accessoryView = field

    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertFirstButtonReturn {
      item.tags = normalize(field.stringValue)
      try? Storage.shared.context.save()
    }
  }
}
