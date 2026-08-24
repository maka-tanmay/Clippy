import SwiftUI
import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings

struct GeneralSettingsPane: View {
  private let notificationsURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(Bundle.main.bundleIdentifier ?? "")"
  )

  @Default(.searchMode) private var searchMode

  @State private var copyModifier = HistoryItemAction.copy.modifierFlags.description
  @State private var pasteModifier = HistoryItemAction.paste.modifierFlags.description
  @State private var pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description

  @State private var updater = SoftwareUpdater()
  @Default(.appendModeEnabled) private var appendModeEnabled
  @Default(.appendModeTimeWindow) private var appendModeTimeWindow
  @State private var importScreenshots = ScreenshotWatcher.shared.isEnabled

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(title: "", bottomDivider: true) {
        LaunchAtLogin.Toggle {
          Text("LaunchAtLogin", tableName: "GeneralSettings")
        }
        Toggle(isOn: $updater.automaticallyChecksForUpdates) {
          Text("CheckForUpdates", tableName: "GeneralSettings")
        }
        Button(
          action: { updater.checkForUpdates() },
          label: { Text("CheckNow", tableName: "GeneralSettings") }
        )
      }

      Settings.Section(label: { Text("Open", tableName: "GeneralSettings") }) {
        KeyboardShortcuts.Recorder(for: .popup, onChange: { newShortcut in
          if newShortcut == nil {
            // No shortcut is recorded. Remove keys monitor
            AppState.shared.popup.deinitEventsMonitor()
          } else {
            // User is using shortcut. Ensure keys monitor is initialized
            AppState.shared.popup.initEventsMonitor()
          }
        })
          .help(Text("OpenTooltip", tableName: "GeneralSettings"))
          .accessibilityLabel(Text("Open", tableName: "GeneralSettings"))
      }

      Settings.Section(label: { Text("Pin", tableName: "GeneralSettings") }) {
        KeyboardShortcuts.Recorder(for: .pin)
          .help(Text("PinTooltip", tableName: "GeneralSettings"))
          .accessibilityLabel(Text("Pin", tableName: "GeneralSettings"))
      }
      Settings.Section(label: { Text("Delete", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .delete)
          .help(Text("DeleteTooltip", tableName: "GeneralSettings"))
          .accessibilityLabel(Text("Delete", tableName: "GeneralSettings"))
      }
      Settings.Section(label: { Text("ShowPreview", tableName: "GeneralSettings") }) {
        KeyboardShortcuts.Recorder(for: .togglePreview)
          .help(Text("ShowPreviewTooltip", tableName: "GeneralSettings"))
          .accessibilityLabel(Text("ShowPreview", tableName: "GeneralSettings"))
      }
      Settings.Section(
        bottomDivider: true,
        label: { Text("capture_region_label", tableName: "Localizable") }
      ) {
        KeyboardShortcuts.Recorder(for: .captureRegion)
          .help(Text("capture_region_tooltip", tableName: "Localizable"))

        Toggle(
          isOn: Binding(
            get: { importScreenshots },
            set: { enabled in
              if enabled {
                ScreenshotWatcher.shared.chooseFolder()
              } else {
                ScreenshotWatcher.shared.stop()
              }
              importScreenshots = ScreenshotWatcher.shared.isEnabled
            }
          ),
          label: { Text("screenshot_watcher_toggle", tableName: "Localizable") }
        )
        Text("screenshot_watcher_description", tableName: "Localizable")
          .controlSize(.small)
          .foregroundStyle(.gray)
          .fixedSize(horizontal: false, vertical: true)
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("AppendMode", tableName: "GeneralSettings") }
      ) {
        Defaults.Toggle(key: .appendModeEnabled) {
          Text("EnableAppendMode", tableName: "GeneralSettings")
        }
        .help(Text("EnableAppendModeTooltip", tableName: "GeneralSettings"))

        HStack {
          Text("AppendModeTimeWindow", tableName: "GeneralSettings")
          TextField("", value: $appendModeTimeWindow, format: .number)
            .frame(width: 60)
          Text("seconds", tableName: "GeneralSettings")
        }
        .disabled(!appendModeEnabled)
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("Search", tableName: "GeneralSettings") }
      ) {
        Picker("", selection: $searchMode) {
          ForEach(Search.Mode.allCases) { mode in
            Text(mode.description)
          }
        }
        .labelsHidden()
        .accessibilityLabel(Text("Search", tableName: "GeneralSettings"))
        .frame(width: 180, alignment: .leading)
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("Behavior", tableName: "GeneralSettings") }
      ) {
        Defaults.Toggle(key: .pasteByDefault) {
          Text("PasteAutomatically", tableName: "GeneralSettings")
        }
        .onChange(refreshModifiers)
        .fixedSize()

        Defaults.Toggle(key: .removeFormattingByDefault) {
          Text("PasteWithoutFormatting", tableName: "GeneralSettings")
        }
        .onChange(refreshModifiers)
        .fixedSize()

        Text(String(
          format: NSLocalizedString("Modifiers", tableName: "GeneralSettings", comment: ""),
          copyModifier, pasteModifier, pasteWithoutFormatting
        ))
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
      }

      Settings.Section(title: "") {
        if let notificationsURL = notificationsURL {
          Link(destination: notificationsURL, label: {
            Text("NotificationsAndSounds", tableName: "GeneralSettings")
          })
        }
      }
    }
  }

  private func refreshModifiers(_ sender: Sendable) {
    copyModifier = HistoryItemAction.copy.modifierFlags.description
    pasteModifier = HistoryItemAction.paste.modifierFlags.description
    pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description
  }
}

#Preview {
  GeneralSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
