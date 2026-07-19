import Defaults
import SwiftUI

struct HistoryItemView: View {
  @Bindable var item: HistoryItemDecorator
  var previous: HistoryItemDecorator?
  var next: HistoryItemDecorator?
  var index: Int

  private var visualIndex: Int? {
    if appState.navigator.isMultiSelectInProgress && item.selectionIndex >= 0 {
      return item.selectionIndex
    }
    return nil
  }

  private var selectionAppearance: SelectionAppearance {
    let previousSelected = previous?.isSelected ?? false
    let nextSelected = next?.isSelected ?? false
    switch (previousSelected, nextSelected) {
    case (true, false):
      return .topConnection
    case (false, true):
      return .bottomConnection
    case (true, true):
      return .topBottomConnection
    default:
      return .none
    }
  }

  @Default(.showHexColorSwatch) private var showHexColorSwatch
  @Environment(AppState.self) private var appState

  private var colorSwatchImage: NSImage? {
    guard showHexColorSwatch else { return nil }
    return ColorImage.from(item.title)
  }

  @available(macOS 26.0, *)
  private func runAIAction(_ action: AIAction) {
    guard let text = item.item.text else { return }

    Task {
      do {
        // The result lands on the clipboard, so it also becomes a history item.
        let result = try await action.run(on: text)
        await Clipboard.shared.copyInMaccy(result)
      } catch {
        Notifier.notify(body: NSLocalizedString("ai_action_failed", comment: ""), sound: nil)
      }
    }
  }

  var body: some View {
    ListItemView(
      id: item.id,
      selectionId: item.id,
      appIcon: item.applicationImage,
      image: item.thumbnailImage,
      accessoryImage: item.thumbnailImage != nil ? nil : colorSwatchImage,
      attributedTitle: item.attributedTitle,
      shortcuts: item.shortcuts,
      isSelected: item.isSelected,
      selectionIndex: visualIndex,
      selectionAppearance: selectionAppearance
    ) {
      Text(verbatim: item.title)
    }
    .onAppear {
      item.ensureThumbnailImage()
    }
    .onTapGesture {
      if NSEvent.modifierFlags.contains(.command) && appState.multiSelectionEnabled {
        appState.navigator.addToSelection(item: item)
      } else {
        Task {
          appState.history.select(item)
        }
      }
    }
    .contextMenu {
      if item.item.text != nil {
        Menu(NSLocalizedString("paste_as", comment: "")) {
          ForEach(PasteTransform.allCases) { transform in
            Button(transform.title) {
              appState.popup.close()
              Clipboard.shared.copy(item.item, transform: transform)
              Clipboard.shared.paste()
            }
          }
        }

        if #available(macOS 26.0, *), AIAction.isAvailable {
          ForEach(AIAction.allCases) { action in
            Button(action.title) {
              runAIAction(action)
            }
          }
        }
      }
    }
  }
}
