import XCTest
import Defaults
@testable import Maccy

@MainActor
class WorkspaceTests: XCTestCase {
  let savedWorkspaces = Defaults[.workspaces]
  let savedActive = Defaults[.activeWorkspace]

  override func tearDown() {
    super.tearDown()
    Defaults[.workspaces] = savedWorkspaces
    Defaults[.activeWorkspace] = savedActive
  }

  private func item(_ text: String, workspace: String?, pin: String? = nil) -> HistoryItem {
    let item = HistoryItem(contents: [HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue,
                                                         value: text.data(using: .utf8))])
    item.workspace = workspace
    item.pin = pin
    return item
  }

  func testNoWorkspacesIsNoOp() {
    Defaults[.workspaces] = []
    let items = [item("a", workspace: nil), item("b", workspace: "Work")]
    // Zero-cost path: everything passes through untouched.
    XCTAssertEqual(Workspace.scope(items).count, 2)
    XCTAssertNil(Workspace.stampForNewItem)
  }

  func testScopeIsolatesUnpinnedButKeepsPins() {
    Defaults[.workspaces] = ["Work"]
    Defaults[.activeWorkspace] = "Work"
    let items = [
      item("default", workspace: nil),      // hidden in Work
      item("work", workspace: "Work"),       // shown
      item("pinnedDefault", workspace: nil, pin: "p") // pinned → always shown
    ]
    let scoped = Workspace.scope(items).compactMap { $0.text }
    XCTAssertEqual(Set(scoped), ["work", "pinnedDefault"])
  }

  func testStampUsesActiveWorkspace() {
    Defaults[.workspaces] = ["Work"]
    Defaults[.activeWorkspace] = "Work"
    XCTAssertEqual(Workspace.stampForNewItem, "Work")
    Defaults[.activeWorkspace] = ""
    XCTAssertNil(Workspace.stampForNewItem) // Default workspace stamps nil
  }
}
