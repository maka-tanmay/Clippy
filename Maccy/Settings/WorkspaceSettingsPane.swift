import Defaults
import SwiftUI

struct WorkspaceSettingsPane: View {
  @Default(.workspaces) private var workspaces
  @Default(.activeWorkspace) private var activeWorkspace
  @State private var newName = ""

  private var trimmedNew: String { newName.trimmingCharacters(in: .whitespaces) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker(selection: $activeWorkspace) {
        Text("workspaces_default", tableName: "Localizable").tag("")
        ForEach(workspaces, id: \.self) { Text($0).tag($0) }
      } label: {
        Text("workspaces_active_label", tableName: "Localizable")
      }
      .frame(maxWidth: 320, alignment: .leading)

      List {
        ForEach(workspaces, id: \.self) { name in
          HStack {
            Text(name)
            Spacer()
            Button {
              remove(name)
            } label: {
              Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
          }
        }
      }
      .frame(minHeight: 150)

      HStack {
        TextField(text: $newName) {
          Text("workspaces_new_placeholder", tableName: "Localizable")
        }
        .onSubmit(add)
        Button(action: add) {
          Text("workspaces_add", tableName: "Localizable")
        }
        .disabled(trimmedNew.isEmpty)
      }

      Text("workspaces_description", tableName: "Localizable")
        .controlSize(.small)
        .foregroundStyle(.gray)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: 500, minHeight: 400, alignment: .topLeading)
    .padding()
  }

  private func add() {
    let name = trimmedNew
    guard !name.isEmpty, !workspaces.contains(name) else { return }
    workspaces.append(name)
    newName = ""
  }

  private func remove(_ name: String) {
    workspaces.removeAll { $0 == name }
    if activeWorkspace == name {
      activeWorkspace = ""
    }
  }
}

#Preview {
  WorkspaceSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
