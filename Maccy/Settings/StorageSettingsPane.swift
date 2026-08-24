import SwiftUI
import Defaults
import Settings

struct StorageSettingsPane: View {
  @Observable
  class ViewModel {
    var saveFiles = false {
      didSet {
        Defaults.withoutPropagation {
          if saveFiles {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.files.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.files.types)
          }
        }
      }
    }

    var saveImages = false {
      didSet {
        Defaults.withoutPropagation {
          if saveImages {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.images.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.images.types)
          }
        }
      }
    }

    var saveText = false {
      didSet {
        Defaults.withoutPropagation {
          if saveText {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.text.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.text.types)
          }
        }
      }
    }

    private var observer: Defaults.Observation?

    init() {
      observer = Defaults.observe(.enabledPasteboardTypes) { change in
        self.saveFiles = change.newValue.isSuperset(of: StorageType.files.types)
        self.saveImages = change.newValue.isSuperset(of: StorageType.images.types)
        self.saveText = change.newValue.isSuperset(of: StorageType.text.types)
      }
    }

    deinit {
      observer?.invalidate()
    }
  }

  @Default(.size) private var size
  @Default(.sortBy) private var sortBy
  @Default(.detectSecrets) private var detectSecrets
  @Default(.expireAfterMinutes) private var expireAfterMinutes
  @Default(.expireRegexps) private var expireRegexps

  @State private var viewModel = ViewModel()
  @State private var storageSize = Storage.shared.size
  @State private var expireRegexpsText = ""

  private let sizeFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 1
    formatter.maximum = 999
    return formatter
  }()

  private let minutesFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 1
    formatter.maximum = 1440
    return formatter
  }()

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(
        bottomDivider: true,
        label: { Text("Save", tableName: "StorageSettings") }
      ) {
        Toggle(
          isOn: $viewModel.saveFiles,
          label: { Text("Files", tableName: "StorageSettings") }
        )
        Toggle(
          isOn: $viewModel.saveImages,
          label: { Text("Images", tableName: "StorageSettings") }
        )
        Toggle(
          isOn: $viewModel.saveText,
          label: { Text("Text", tableName: "StorageSettings") }
        )
        Text("SaveDescription", tableName: "StorageSettings")
          .controlSize(.small)
          .foregroundStyle(.gray)
      }

      Settings.Section(label: { Text("Size", tableName: "StorageSettings") }) {
        HStack {
          TextField("", value: $size, formatter: sizeFormatter)
            .frame(width: 80)
            .help(Text("SizeTooltip", tableName: "StorageSettings"))
            .accessibilityLabel(Text("Size", tableName: "StorageSettings"))
          Stepper("", value: $size, in: 1...999)
            .labelsHidden()
            .accessibilityLabel(Text("Size", tableName: "StorageSettings"))
          Text(storageSize)
            .controlSize(.small)
            .foregroundStyle(.gray)
            .help(Text("CurrentSizeTooltip", tableName: "StorageSettings"))
            .onAppear {
              storageSize = Storage.shared.size
            }
        }
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("SortBy", tableName: "StorageSettings") }
      ) {
        Picker("", selection: $sortBy) {
          ForEach(Sorter.By.allCases) { mode in
            Text(mode.description)
          }
        }
        .labelsHidden()
        .frame(width: 160, alignment: .leading)
        .help(Text("SortByTooltip", tableName: "StorageSettings"))
        .accessibilityLabel(Text("SortBy", tableName: "StorageSettings"))
      }

      Settings.Section(label: { Text("privacy_section_label", tableName: "Localizable") }) {
        Toggle(
          isOn: $detectSecrets,
          label: { Text("detect_secrets_toggle", tableName: "Localizable") }
        )

        HStack {
          Text("expire_rules_label", tableName: "Localizable")
          TextField("", value: $expireAfterMinutes, formatter: minutesFormatter)
            .frame(width: 50)
          Text("expire_rules_minutes", tableName: "Localizable")
        }

        TextField(
          "",
          text: $expireRegexpsText,
          prompt: Text(verbatim: "^\\d{6}$"),
          axis: .vertical
        )
        .lineLimit(3...5)
        .onChange(of: expireRegexpsText) {
          expireRegexps = expireRegexpsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        }
        .onAppear {
          expireRegexpsText = expireRegexps.joined(separator: "\n")
        }

        Text("privacy_section_description", tableName: "Localizable")
          .controlSize(.small)
          .foregroundStyle(.gray)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

#Preview {
  StorageSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
