import AppKit
import Defaults

// swiftlint:disable identifier_name
// swiftlint:disable type_name
class Sorter {
  enum By: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
    case lastCopiedAt
    case firstCopiedAt
    case numberOfCopies

    var id: Self { self }

    var description: String {
      switch self {
      case .lastCopiedAt:
        return NSLocalizedString("LastCopiedAt", tableName: "StorageSettings", comment: "")
      case .firstCopiedAt:
        return NSLocalizedString("FirstCopiedAt", tableName: "StorageSettings", comment: "")
      case .numberOfCopies:
        return NSLocalizedString("NumberOfCopies", tableName: "StorageSettings", comment: "")
      }
    }
  }

  func sort(_ items: [HistoryItem], by: By = Defaults[.sortBy]) -> [HistoryItem] {
    let sorted = items.sorted(by: { return bySortingAlgorithm($0, $1, by) })
    // Pinned items keep a user-controlled manual order (pinnedOrder). When it's
    // unset (all 0) the stable sort preserves the normal order, so nothing
    // changes until the user reorders pins.
    let pinned = sorted.filter { $0.pin != nil }.sorted(by: { $0.pinnedOrder < $1.pinnedOrder })
    let unpinned = sorted.filter { $0.pin == nil }
    return Defaults[.pinTo] == .bottom ? unpinned + pinned : pinned + unpinned
  }

  private func bySortingAlgorithm(_ lhs: HistoryItem, _ rhs: HistoryItem, _ by: By) -> Bool {
    switch by {
    case .firstCopiedAt:
      return lhs.firstCopiedAt > rhs.firstCopiedAt
    case .numberOfCopies:
      return lhs.numberOfCopies > rhs.numberOfCopies
    default:
      return lhs.lastCopiedAt > rhs.lastCopiedAt
    }
  }
}
// swiftlint:enable identifier_name
// swiftlint:enable type_name
