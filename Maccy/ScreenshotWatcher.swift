import AppKit
import Defaults
import Darwin
import ImageIO
import UniformTypeIdentifiers

// Read screenshot metadata directly; no dependency on Spotlight indexing.
@MainActor
class ScreenshotWatcher: NSObject {
  static let shared = ScreenshotWatcher()
  private var watchTask: Task<Void, Never>?
  private var scopedURL: URL?
  var isEnabled: Bool { Defaults[.screenshotsFolderBookmark] != nil }

  func start() {
    guard scopedURL == nil, !AppDelegate.isTesting,
          let bookmark = Defaults[.screenshotsFolderBookmark] else { return }
    var isStale = false
    do {
      let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope,
                        relativeTo: nil, bookmarkDataIsStale: &isStale)
      guard url.startAccessingSecurityScopedResource() else { return }
      scopedURL = url
      if isStale {
        Defaults[.screenshotsFolderBookmark] = try url.bookmarkData(options: .withSecurityScope)
      }
      watchTask = Task { [weak self] in
        let worker = Task.detached(priority: .utility) { [weak self] in
          var seen = Set((try? FileManager.default.contentsOfDirectory(at: url,
            includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [])
          while !Task.isCancelled {
            do { try await Task.sleep(for: .milliseconds(750)) } catch { return }
            guard let files = try? FileManager.default.contentsOfDirectory(at: url,
              includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            let current = Set(files)
            let added = current.subtracting(seen).sorted { $0.lastPathComponent < $1.lastPathComponent }
            seen = current
            for file in added {
              guard ["png", "jpg", "jpeg", "heic", "tiff", "tif"].contains(file.pathExtension.lowercased())
              else { continue }
              guard !Task.isCancelled else { return }
              let count = await MainActor.run { NSPasteboard.general.changeCount }
              // Retry incomplete writes and metadata arriving after the file.
              for _ in 0..<12 {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                guard let png = Self.screenshotPNG(at: file) else { continue }
                // Do not change the pasteboard during an active drag.
                while await MainActor.run(body: { NSEvent.pressedMouseButtons != 0 }) {
                  do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                await self?.copyScreenshot(png, expectedChangeCount: count)
                break
              }
            }
          }
        }
        await withTaskCancellationHandler {
          await worker.value
        } onCancel: {
          worker.cancel()
        }
      }
    } catch {
      NSLog("Unable to watch screenshots: %@", error.localizedDescription)
      stopWatching()
    }
  }

  private func stopWatching() {
    watchTask?.cancel()
    watchTask = nil
    scopedURL?.stopAccessingSecurityScopedResource()
    scopedURL = nil
  }

  func stop() {
    stopWatching()
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
          let bookmark = try? url.bookmarkData(options: .withSecurityScope) else { return }
    stopWatching()
    Defaults[.screenshotsFolderBookmark] = bookmark
    start()
  }

  nonisolated static func screenshotPNG(at url: URL) -> Data? {
    guard getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0,
          let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetStatus(source) == .statusComplete,
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
  }

  func copyScreenshot(_ png: Data, expectedChangeCount: Int) {
    guard !Defaults[.ignoreEvents], Defaults[.enabledPasteboardTypes].contains(.png),
          NSPasteboard.general.changeCount == expectedChangeCount else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setData(png, forType: .png)
    NSPasteboard.general.setString("com.apple.screencaptureui", forType: .source)
    Clipboard.shared.checkForChangesInPasteboard()
  }
}
