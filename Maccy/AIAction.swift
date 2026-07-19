import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// On-device AI actions for history items. Strictly gated: the menu only
// appears on macOS 26+ with Apple Intelligence available; nothing ever
// leaves the machine.
@available(macOS 26.0, *)
enum AIAction: String, CaseIterable, Identifiable {
  case summarize, explainCode

  var id: String { rawValue }

  var title: String {
    switch self {
    case .summarize: NSLocalizedString("ai_action_summarize", comment: "")
    case .explainCode: NSLocalizedString("ai_action_explain_code", comment: "")
    }
  }

  static var isAvailable: Bool {
    #if canImport(FoundationModels)
    if case .available = SystemLanguageModel.default.availability {
      return true
    }
    #endif
    return false
  }

  private var instructions: String {
    switch self {
    case .summarize:
      "Summarize the following text in a few short sentences. Reply with the summary only."
    case .explainCode:
      "Explain what the following code does, briefly and plainly. Reply with the explanation only."
    }
  }

  func run(on text: String) async throws -> String {
    #if canImport(FoundationModels)
    let session = LanguageModelSession(instructions: instructions)
    return try await session.respond(to: text).content
    #else
    throw NSError(domain: "clippy.ai", code: 1)
    #endif
  }
}
