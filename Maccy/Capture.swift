import AppKit
import ScreenCaptureKit

// Region screenshot straight to the clipboard. The regular Clipboard polling
// then ingests it into history like any other copy (and OCR makes it searchable).
@MainActor
class ScreenCapture {
  static let shared = ScreenCapture()

  private var overlays: [CaptureOverlayPanel] = []

  func captureRegion() {
    guard overlays.isEmpty else { return }

    for screen in NSScreen.screens {
      let panel = CaptureOverlayPanel(screen: screen) { [weak self] rect in
        self?.dismissOverlays()
        Task { await self?.capture(rect: rect, on: screen) }
      } onCancel: { [weak self] in
        self?.dismissOverlays()
      }
      panel.makeKeyAndOrderFront(nil)
      overlays.append(panel)
    }
  }

  private func dismissOverlays() {
    overlays.forEach { $0.orderOut(nil) }
    overlays = []
  }

  // `rect` is in the overlay view's coordinates (bottom-left origin, points),
  // which match the screen because the overlay covers it entirely.
  private func capture(rect: CGRect, on screen: NSScreen) async {
    do {
      let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
      guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
            let display = content.displays.first(where: { $0.displayID == displayID }) else {
        return
      }

      let configuration = SCStreamConfiguration()
      // SCStreamConfiguration.sourceRect wants top-left origin, display-local points.
      configuration.sourceRect = CGRect(
        x: rect.minX,
        y: screen.frame.height - rect.maxY,
        width: rect.width,
        height: rect.height
      )
      let scale = screen.backingScaleFactor
      configuration.width = Int(rect.width * scale)
      configuration.height = Int(rect.height * scale)
      configuration.showsCursor = false

      let image = try await SCScreenshotManager.captureImage(
        contentFilter: SCContentFilter(display: display, excludingWindows: []),
        configuration: configuration
      )
      copyToPasteboard(image)
    } catch {
      Notifier.notify(body: NSLocalizedString("capture_failed", comment: ""), sound: nil)
    }
  }

  private func copyToPasteboard(_ cgImage: CGImage) {
    guard let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
      return
    }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setData(png, forType: .png)
  }
}

// ponytail: one overlay per screen, selection cannot span displays; good enough
// until someone actually drags across monitors.
private class CaptureOverlayPanel: NSPanel {
  init(screen: NSScreen, onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
    super.init(
      contentRect: screen.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    level = .screenSaver
    isOpaque = false
    hasShadow = false
    backgroundColor = .clear
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    contentView = CaptureSelectionView(onSelect: onSelect, onCancel: onCancel)
  }

  override var canBecomeKey: Bool { true }
}

private class CaptureSelectionView: NSView {
  private let onSelect: (CGRect) -> Void
  private let onCancel: () -> Void

  private var startPoint: NSPoint?
  private var currentPoint: NSPoint?

  private var selectionRect: CGRect? {
    guard let start = startPoint, let current = currentPoint else { return nil }
    return CGRect(
      x: min(start.x, current.x),
      y: min(start.y, current.y),
      width: abs(start.x - current.x),
      height: abs(start.y - current.y)
    )
  }

  init(onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
    self.onSelect = onSelect
    self.onCancel = onCancel
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var acceptsFirstResponder: Bool { true }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .crosshair)
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.withAlphaComponent(0.25).setFill()
    bounds.fill()

    if let rect = selectionRect {
      NSColor.clear.setFill()
      rect.fill(using: .copy)

      NSColor.white.setStroke()
      let border = NSBezierPath(rect: rect)
      border.lineWidth = 1
      border.stroke()
    }
  }

  override func mouseDown(with event: NSEvent) {
    startPoint = convert(event.locationInWindow, from: nil)
    currentPoint = startPoint
    needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    currentPoint = convert(event.locationInWindow, from: nil)
    needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    defer {
      startPoint = nil
      currentPoint = nil
    }

    if let rect = selectionRect, rect.width > 3, rect.height > 3 {
      onSelect(rect)
    } else {
      onCancel()
    }
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 { // Esc
      onCancel()
    } else {
      super.keyDown(with: event)
    }
  }
}
