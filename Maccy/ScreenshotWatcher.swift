import AppKit
import Defaults

// Imports screenshots taken with the system tool (⇧⌘3/4/5) into history,
// where OCR makes them searchable. macOS writes those to a folder without
// ever touching the clipboard, so we watch the folder via Spotlight's
// kMDItemIsScreenCapture flag. The sandbox requires the user to pick the
// folder once; access persists via a security-scoped bookmark.
@MainActor
class ScreenshotWatcher: NSObject {
  static let shared = ScreenshotWatcher()

  private let query = NSMetadataQuery()
  private var scopedURL: URL?

  var isEnabled: Bool { Defaults[.screenshotsFolderBookmark] != nil }

  func start() {
    guard scopedURL == nil, let bookmark = Defaults[.screenshotsFolderBookmark] else { return }

    var isStale = false
    guard let url = try? URL(
      resolvingBookmarkData: bookmark,
      options: .withSecurityScope,
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    ) else {
      Defaults[.screenshotsFolderBookmark] = nil
      return
    }
    if isStale, let fresh = try? url.bookmarkData(options: .withSecurityScope) {
      Defaults[.screenshotsFolderBookmark] = fresh
    }
    guard url.startAccessingSecurityScopedResource() else { return }
    scopedURL = url

    query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
    query.searchScopes = [url]
    query.notificationBatchingInterval = 1
    // Only DidUpdate matters: the initial gathering phase returns every old
    // screenshot in the folder, which must not be imported.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(queryDidUpdate),
      name: .NSMetadataQueryDidUpdate,
      object: query
    )
    query.start()
  }

  func stop() {
    query.stop()
    NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
    scopedURL?.stopAccessingSecurityScopedResource()
    scopedURL = nil
    Defaults[.screenshotsFolderBookmark] = nil
  }

  func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    panel.message = NSLocalizedString("screenshot_watcher_panel_message", comment: "")
    panel.prompt = NSLocalizedString("screenshot_watcher_panel_prompt", comment: "")

    NSApp.activate(ignoringOtherApps: true)
    guard panel.runModal() == .OK, let url = panel.url,
          let bookmark = try? url.bookmarkData(options: .withSecurityScope) else {
      return
    }

    Defaults[.screenshotsFolderBookmark] = bookmark
    start()
  }

  @objc
  private func queryDidUpdate(_ notification: Notification) {
    guard let added = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] else {
      return
    }

    for result in added {
      guard let path = result.value(forAttribute: NSMetadataItemPathKey as String) as? String else { continue }
      Task { @MainActor in
        await self.importScreenshot(URL(fileURLWithPath: path))
      }
    }
  }

  private func importScreenshot(_ url: URL) async {
    // The floating thumbnail delays the final write; retry briefly.
    var data = try? Data(contentsOf: url)
    for _ in 0..<3 where data == nil {
      try? await Task.sleep(for: .seconds(2))
      data = try? Data(contentsOf: url)
    }
    guard let data, NSImage(data: data) != nil else { return }

    let content = HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: data)
    let item = HistoryItem(contents: [content])

    if #unavailable(macOS 15.0) {
      try? History.shared.insertIntoStorage(item)
    }

    item.application = "com.apple.screencaptureui"
    item.title = item.generateTitle()

    History.shared.add(item)
  }
}
