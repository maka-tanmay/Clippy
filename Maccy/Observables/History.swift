// swiftlint:disable file_length
import AppKit.NSRunningApplication
import Defaults
import Foundation
import Logging
import Observation
import Sauce
import Settings
import SwiftData

@Observable
class History: ItemsContainer { // swiftlint:disable:this type_body_length
  static let shared = History()
  let logger = Logger(label: "com.tanmaymaka.clippy")

  var items: [HistoryItemDecorator] = []
  var pasteStack: PasteStack?

  var pinnedItems: [HistoryItemDecorator] { items.filter(\.isPinned) }
  var unpinnedItems: [HistoryItemDecorator] { items.filter(\.isUnpinned) }

  var searchQuery: String = "" {
    didSet {
      throttler.throttle { [self] in
        let (typeFilter, afterType) = ContentType.parse(query: searchQuery)
        let (tagFilter, query) = ItemTag.parse(query: afterType)
        var scope = typeFilter.map { type in all.filter { $0.contentType == type } } ?? all
        if let tagFilter {
          scope = scope.filter { $0.item.tags.contains { $0.caseInsensitiveCompare(tagFilter) == .orderedSame } }
        }
        updateItems(search.search(string: query, within: scope))

        if searchQuery.isEmpty {
          AppState.shared.navigator.select(item: unpinnedItems.first)
        } else {
          AppState.shared.navigator.highlightFirst()
        }

        AppState.shared.popup.needsResize = true
      }
    }
  }

  var pressedShortcutItem: HistoryItemDecorator? {
    guard let event = NSApp.currentEvent else {
      return nil
    }

    let modifierFlags = event.modifierFlags
      .intersection(.deviceIndependentFlagsMask)
      .subtracting(.capsLock)

    guard HistoryItemAction(modifierFlags) != .unknown else {
      return nil
    }

    let key = Sauce.shared.key(for: Int(event.keyCode))
    return items.first { $0.shortcuts.contains(where: { $0.key == key }) }
  }

  private let search = Search()
  private let sorter = Sorter()
  private let throttler = Throttler(minimumDelay: 0.2)

  @ObservationIgnored
  private var sessionLog: [Int: HistoryItem] = [:]

  // The distinction between `all` and `items` is the following:
  // - `all` stores all history items, even the ones that are currently hidden by a search
  // - `items` stores only visible history items, updated during a search
  @ObservationIgnored
  var all: [HistoryItemDecorator] = []

  init() {
    Task {
      for await _ in Defaults.updates(.pasteByDefault, initial: false) {
        updateShortcuts()
      }
    }

    Task {
      for await _ in Defaults.updates(.sortBy, initial: false) {
        try? await load()
      }
    }

    Task {
      for await _ in Defaults.updates(.pinTo, initial: false) {
        try? await load()
      }
    }

    Task {
      for await _ in Defaults.updates(.showSpecialSymbols, initial: false) {
        for item in items {
          await updateTitle(item: item, title: item.item.generateTitle())
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.imageMaxHeight, initial: false) {
        for item in items {
          await item.cleanupImages()
        }
      }
    }
  }

  @ObservationIgnored
  private var expirySweeper: Timer?

  @MainActor
  func load() async throws {
    let descriptor = FetchDescriptor<HistoryItem>()
    let results = try Storage.shared.context.fetch(descriptor)
    all = sorter.sort(results).map { HistoryItemDecorator($0) }
    items = all

    limitHistorySize(to: Defaults[.size])
    startExpirySweeper()

    updateShortcuts()
    // Ensure that panel size is proper *after* loading all items.
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  private func startExpirySweeper() {
    guard expirySweeper == nil else { return }

    sweepExpired()
    expirySweeper = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
      Task { @MainActor in
        History.shared.sweepExpired()
      }
    }
  }

  @MainActor
  func sweepExpired() {
    let now = Date.now
    let expired = all.filter { decorator in
      guard let expiresAt = decorator.item.expiresAt else { return false }
      return expiresAt <= now
    }
    guard !expired.isEmpty else { return }

    for decorator in expired {
      logger.info("Expiring item '\(decorator.item.title)'")
      // Shred the live clipboard too if it still holds the expired content,
      // regardless of the clearSystemClipboard setting — that's the point.
      if let text = decorator.item.text, NSPasteboard.general.string(forType: .string) == text {
        NSPasteboard.general.clearContents()
      }
      delete(decorator)
    }
  }

  @MainActor
  private func limitHistorySize(to maxSize: Int) {
    let unpinned = all.filter(\.isUnpinned)
    if unpinned.count >= maxSize {
      unpinned[maxSize...].forEach(delete)
    }
  }

  @MainActor
  func insertIntoStorage(_ item: HistoryItem) throws {
    logger.info("Inserting item with id '\(item.title)'")
    Storage.shared.context.insert(item)
    Storage.shared.context.processPendingChanges()
    try? Storage.shared.context.save()
  }

  // Folds `item`'s text onto the most recent different unpinned text item,
  // updating the live clipboard to the combined text. Returns nil (fall back to
  // a normal add) when there's nothing suitable to append to.
  @MainActor
  private func appendToPreviousItem(_ item: HistoryItem) -> HistoryItemDecorator? {
    guard let newText = item.text else { return nil }

    let candidate = all
      .filter { $0.item.pin == nil && $0.item.text != nil && $0.item.text != newText }
      .max(by: { $0.item.lastCopiedAt < $1.item.lastCopiedAt })
    guard let target = candidate,
          let existingText = target.item.text,
          let stringContent = target.item.contents.first(where: {
            NSPasteboard.PasteboardType($0.type) == .string
          }) else {
      return nil
    }

    let combinedText = existingText + "\n" + newText
    stringContent.value = combinedText.data(using: .utf8)
    target.item.lastCopiedAt = Date.now
    target.item.numberOfCopies += 1
    target.item.title = target.item.generateTitle()
    target.title = target.item.title

    Storage.shared.context.delete(item)
    items = all

    // Reflect the combined text on the system clipboard without re-recording it.
    Defaults[.ignoreOnlyNextEvent] = true
    Defaults[.ignoreEvents] = true
    Clipboard.shared.copyInMaccy(combinedText)

    return target
  }

  @discardableResult
  @MainActor
  func add(_ item: HistoryItem, shouldAppend: Bool = false) -> HistoryItemDecorator {
    if #available(macOS 15.0, *) {
      try? History.shared.insertIntoStorage(item)
    } else {
      // On macOS 14 the history item needs to be inserted into storage directly after creating it.
      // It was already inserted after creation in Clipboard.swift
    }

    // Append mode (double-tap ⌘C): fold this copy onto the most recent
    // different unpinned text item instead of creating a new entry.
    if shouldAppend, let appended = appendToPreviousItem(item) {
      return appended
    }

    var removedItemIndex: Int?
    if let existingHistoryItem = findSimilarItem(item) {
      if isModified(item) == nil {
        transferContents(from: existingHistoryItem, to: item)
      }
      item.firstCopiedAt = existingHistoryItem.firstCopiedAt
      item.numberOfCopies += existingHistoryItem.numberOfCopies
      item.pin = existingHistoryItem.pin
      item.title = existingHistoryItem.title
      if !item.fromMaccy {
        item.application = existingHistoryItem.application
      }
      logger.info("Removing duplicate item '\(item.title)'")
      removedItemIndex = all.firstIndex(where: { $0.item == existingHistoryItem })
      if let removedItemIndex {
        cleanup(all[removedItemIndex])
      }
      deleteFromStorage(existingHistoryItem)
      if let removedItemIndex {
        all.remove(at: removedItemIndex)
      }

      // Suggest pinning once, when the item crosses the repeat-copy threshold.
      if item.pin == nil && item.numberOfCopies == 5 {
        Task {
          Notifier.notify(
            body: String(format: NSLocalizedString("pin_suggestion", comment: ""), item.title.shortened(to: 40)),
            sound: nil
          )
        }
      }
    } else {
      Task {
        Notifier.notify(body: item.title, sound: .write)
      }
    }

    // Remove exceeding items. Do this after the item is added to avoid removing something
    // if a duplicate was found as then the size already stayed the same.
    limitHistorySize(to: Defaults[.size] - 1)

    sessionLog[Clipboard.shared.changeCount] = item

    var itemDecorator: HistoryItemDecorator
    if let pin = item.pin {
      itemDecorator = HistoryItemDecorator(item, shortcuts: KeyShortcut.create(character: pin))
      if let removedItemIndex {
        // If pin to bottom -> last element should be inserted to the removedItemIndex - 1
        // Or to the last all array place.
        all.insert(itemDecorator, at: min(removedItemIndex, all.count))
      }
    } else {
      itemDecorator = HistoryItemDecorator(item)

      let sortedItems = sorter.sort(all.map(\.item) + [item])
      if let index = sortedItems.firstIndex(of: item) {
        all.insert(itemDecorator, at: index)
      }

      items = all
      updateUnpinnedShortcuts()
      AppState.shared.popup.needsResize = true
    }

    return itemDecorator
  }

  @MainActor
  private func withLogging(_ msg: String, _ block: () throws -> Void) rethrows {
    func dataCounts() -> String {
      let historyItemCount = try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItem>())
      let historyContentCount = try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItemContent>())
      return "HistoryItem=\(historyItemCount ?? 0) HistoryItemContent=\(historyContentCount ?? 0)"
    }

    logger.info("\(msg) Before: \(dataCounts())")
    try? block()
    logger.info("\(msg) After: \(dataCounts())")
  }

  @MainActor
  func clear() {
    withLogging("Clearing history") {
      all.forEach { item in
        if item.isUnpinned {
          cleanup(item)
        }
      }
      all.removeAll(where: \.isUnpinned)
      sessionLog.removeValues { $0.pin == nil }
      items = all

      try? Storage.shared.context.transaction {
        try? Storage.shared.context.delete(
          model: HistoryItem.self,
          where: #Predicate { $0.pin == nil }
        )
        try? Storage.shared.context.delete(
          model: HistoryItemContent.self,
          where: #Predicate { $0.item?.pin == nil }
        )
      }
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }

    Clipboard.shared.clear()
    AppState.shared.popup.close()
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  func clearAll() {
    withLogging("Clearing all history") {
      all.forEach { item in
        cleanup(item)
      }
      all.removeAll()
      sessionLog.removeAll()
      items = all

      do {
        let context = Storage.shared.context
        try context.transaction {
          // Bulk deletion cannot remove children with live inverse relationships.
          try context.delete(
            model: HistoryItemContent.self,
            where: #Predicate { $0.item == nil }
          )
          try context.delete(model: HistoryItem.self)
          try context.delete(model: HistoryItemContent.self)
        }
      } catch {
        logger.error("Failed to clear storage: \(String(reflecting: error))")
      }
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }

    Clipboard.shared.clear()
    AppState.shared.popup.close()
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  func delete(_ item: HistoryItemDecorator?) {
    guard let item else { return }

    cleanup(item)
    withLogging("Removing history item") {
      deleteFromStorage(item.item)
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }

    all.removeAll { $0 == item }
    items.removeAll { $0 == item }
    sessionLog.removeValues { $0 == item.item }

    updateUnpinnedShortcuts()
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  private func transferContents(from existingItem: HistoryItem, to newItem: HistoryItem) {
    deleteContents(of: newItem)
    newItem.contents = existingItem.contents
    existingItem.contents = []
  }

  @MainActor
  private func deleteFromStorage(_ item: HistoryItem) {
    deleteContents(of: item)
    Storage.shared.context.delete(item)
  }

  @MainActor
  private func deleteContents(of item: HistoryItem) {
    item.contents.forEach(Storage.shared.context.delete)
  }

  @MainActor
  private func cleanup(_ item: HistoryItemDecorator) {
    item.cleanupImages()
  }

  @MainActor
  func select(_ item: HistoryItemDecorator?, flags modifierFlags: NSEvent.ModifierFlags) {
    guard let item else {
      return
    }

    if modifierFlags.isEmpty {
      AppState.shared.popup.close()
      Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
      if Defaults[.pasteByDefault] {
        Clipboard.shared.paste()
      }
    } else {
      switch HistoryItemAction(modifierFlags) {
      case .copy:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
      case .paste:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
        Clipboard.shared.paste()
      case .pasteWithoutFormatting:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item, removeFormatting: true)
        Clipboard.shared.paste()
      case .unknown:
        return
      }
    }

    Task {
      searchQuery = ""
    }
  }

  @MainActor
  func startPasteStack(selection: inout Selection<HistoryItemDecorator>, flags modifierFlags: NSEvent.ModifierFlags) {
    guard AppState.shared.multiSelectionEnabled else { return }
    guard let item = selection.first else { return }
    PasteStack.initializeIfNeeded()

    let stack = PasteStack(items: selection.items, modifierFlags: modifierFlags)
    pasteStack = stack

    logger.info("Initialising PasteStack with \(stack.items.count) items")
    logger.info("Copying \(item.item.title) from PasteStack")

    if modifierFlags.isEmpty {
      AppState.shared.popup.close()
      Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
    } else {
      switch HistoryItemAction(modifierFlags) {
      case .copy:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
      case .paste:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
      case .pasteWithoutFormatting:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item, removeFormatting: true)
        Clipboard.shared.paste()
      case .unknown:
        return
      }
    }

    Task {
      searchQuery = ""
    }
  }

  func handlePasteStack() {
    guard let stack = pasteStack else {
      return
    }

    guard let pasted = stack.items.first else {
      pasteStack = nil
      logger.info("PasteStack is empty")
      return
    }

    logger.info("PasteStack pasted \(pasted.item.title)")

    stack.items.removeFirst()

    guard let item = stack.items.first else {
      pasteStack = nil
      logger.info("PasteStack is empty")
      return
    }

    logger.info("Copying \(item.item.title) from PasteStack. \(stack.items.count) items remaining in stack.")

    Task {
      if stack.modifierFlags.isEmpty {
        await Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
      } else {
        switch HistoryItemAction(stack.modifierFlags) {
        case .copy:
          await Clipboard.shared.copy(item.item)
        case .paste:
          await Clipboard.shared.copy(item.item)
        case .pasteWithoutFormatting:
          await Clipboard.shared.copy(item.item, removeFormatting: true)
        case .unknown:
          return
        }
      }
    }
  }

  func interruptPasteStack() {
    guard pasteStack != nil else {
      return
    }
    logger.info("Interrupting PasteStack")
    pasteStack = nil
  }

  @MainActor
  func togglePin(_ item: HistoryItemDecorator?) {
    guard let item else { return }

    item.togglePin()

    let sortedItems = sorter.sort(all.map(\.item))
    if let currentIndex = all.firstIndex(of: item),
       let newIndex = sortedItems.firstIndex(of: item.item) {
      all.remove(at: currentIndex)
      all.insert(item, at: newIndex)
    }

    items = all

    searchQuery = ""
    updateUnpinnedShortcuts()
    if item.isUnpinned {
      AppState.shared.navigator.scrollTarget = item.id
    }
  }

  // Moves a pinned item up or down in the manual pin order. Reassigns
  // sequential pinnedOrder values on each move so it works even for pins that
  // predate the field (all zero).
  @MainActor
  func movePinned(_ item: HistoryItemDecorator, up: Bool) {
    var pins = all.filter(\.isPinned).sorted { $0.item.pinnedOrder < $1.item.pinnedOrder }
    guard let idx = pins.firstIndex(of: item) else { return }
    let target = up ? idx - 1 : idx + 1
    guard pins.indices.contains(target) else { return }

    pins.swapAt(idx, target)
    for (order, pin) in pins.enumerated() {
      pin.item.pinnedOrder = order
    }
    try? Storage.shared.context.save()

    let sortedItems = sorter.sort(all.map(\.item))
    all.sort { (sortedItems.firstIndex(of: $0.item) ?? 0) < (sortedItems.firstIndex(of: $1.item) ?? 0) }
    items = all
    updateUnpinnedShortcuts()
  }

  @MainActor
  private func findSimilarItem(_ item: HistoryItem) -> HistoryItem? {
    if let duplicate = all.first(where: { $0.item != item && $0.item.supersedes(item) }) {
      return duplicate.item
    }

    return isModified(item)
  }

  private func isModified(_ item: HistoryItem) -> HistoryItem? {
    if let modified = item.modified, sessionLog.keys.contains(modified) {
      return sessionLog[modified]
    }

    return nil
  }

  private func updateItems(_ newItems: [Search.SearchResult]) {
    items = newItems.map { result in
      let item = result.object
      item.highlight(searchQuery, result.ranges)

      return item
    }

    updateUnpinnedShortcuts()
  }

  private func updateShortcuts() {
    for item in pinnedItems {
      if let pin = item.item.pin {
        item.shortcuts = KeyShortcut.create(character: pin)
      }
    }

    updateUnpinnedShortcuts()
  }

  @MainActor
  private func updateTitle(item: HistoryItemDecorator, title: String) {
    item.title = title
    item.item.title = title
  }

  private func updateUnpinnedShortcuts() {
    let visibleUnpinnedItems = unpinnedItems.filter(\.isVisible)
    for item in visibleUnpinnedItems {
      item.shortcuts = []
    }

    var index = 1
    for item in visibleUnpinnedItems.prefix(9) {
      item.shortcuts = KeyShortcut.create(character: String(index))
      index += 1
    }
  }
}
