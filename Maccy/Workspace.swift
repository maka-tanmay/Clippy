import Defaults
import Foundation

// Clipboard isolation: unpinned history is scoped to the active workspace,
// while pinned items stay visible everywhere (global snippets).
//
// Speed: when the user has created no workspaces — the default and common
// case — every entry point short-circuits, so there is zero added cost on
// the copy/load hot paths.
enum Workspace {
  static var hasWorkspaces: Bool { !Defaults[.workspaces].isEmpty }

  static var active: String { Defaults[.activeWorkspace] }

  // The workspace value to stamp on a newly copied item (nil = default).
  static var stampForNewItem: String? {
    guard hasWorkspaces else { return nil }
    let active = Defaults[.activeWorkspace]
    return active.isEmpty ? nil : active
  }

  // Filters items to the active workspace. Pins are always kept.
  static func scope(_ items: [HistoryItem]) -> [HistoryItem] {
    guard hasWorkspaces else { return items }
    let active = Defaults[.activeWorkspace]
    return items.filter { $0.pin != nil || ($0.workspace ?? "") == active }
  }

  static func belongs(_ item: HistoryItem, to workspace: String) -> Bool {
    item.pin != nil || (item.workspace ?? "") == workspace
  }
}
