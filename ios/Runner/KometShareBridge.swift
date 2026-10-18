import Flutter
import UIKit

final class KometShareBridge {
  private let queue = DispatchQueue(label: "ru.komet.app.share", qos: .userInitiated)
  private var store: KometShareStore?
  private var sink: FlutterEventSink?
  private let extensionEnabled = Bundle.main.object(forInfoDictionaryKey: "KometShareExtensionEnabled") as? Bool != false

  func attach(_ sink: FlutterEventSink?) {
    self.sink = sink
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if !extensionEnabled && ["syncShareAccount", "invalidateShareAccount", "invalidateShareAccounts", "clearShareAccount", "clearAllShareAccounts", "readShareToken"].contains(call.method) {
      result(nil)
      return
    }
    switch call.method {
    case "consumeInitialShare":
      perform(result) { try $0.nextPayload() }
    case "acknowledgeShare":
      guard let id = (call.arguments as? [String: Any])?["id"] as? String else {
        result(FlutterError(code: "INVALID_SHARE", message: "Missing share ID", details: nil))
        return
      }
      perform(result) { store in
        try store.acknowledge(id: id)
        return nil
      }
    case "releaseShare":
      guard let id = (call.arguments as? [String: Any])?["id"] as? String else {
        result(FlutterError(code: "INVALID_SHARE", message: "Missing share ID", details: nil))
        return
      }
      perform(result) { store in
        try store.removeCompleted(id: id)
        return nil
      }
    case "syncShareAccount":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_SHARE_ACCOUNT", message: "Missing share account", details: nil))
        return
      }
      perform(result) { _ in
        try KometShareAccounts().sync(arguments)
        return nil
      }
    case "invalidateShareAccounts":
      perform(result) { _ in
        try KometShareAccounts().invalidate(accountID: nil)
        return nil
      }
    case "invalidateShareAccount":
      guard let id = (call.arguments as? [String: Any])?["accountId"] as? String else {
        result(FlutterError(code: "INVALID_SHARE_ACCOUNT", message: "Missing account ID", details: nil))
        return
      }
      perform(result) { _ in
        try KometShareAccounts().invalidate(accountID: id)
        return nil
      }
    case "clearShareAccount":
      guard let id = (call.arguments as? [String: Any])?["accountId"] as? String else {
        result(FlutterError(code: "INVALID_SHARE_ACCOUNT", message: "Missing account ID", details: nil))
        return
      }
      perform(result) { _ in
        try KometShareAccounts().clear(accountID: id)
        return nil
      }
    case "clearAllShareAccounts":
      perform(result) { _ in
        try KometShareAccounts().clear(accountID: nil)
        return nil
      }
    case "readShareToken":
      guard let arguments = call.arguments as? [String: Any],
            let id = arguments["accountId"] as? String,
            let knownToken = arguments["knownToken"] as? String else {
        result(FlutterError(code: "INVALID_SHARE_ACCOUNT", message: "Missing account credentials", details: nil))
        return
      }
      perform(result) { _ in
        try KometShareAccounts().refreshedToken(accountID: id, knownToken: knownToken)
      }
    case "shareDirectory":
      perform(result) { _ in
        let group = Bundle.main.object(forInfoDictionaryKey: "KometShareAppGroup") as? String ?? "group.ru.komet.app"
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
          return nil
        }
        return container.appendingPathComponent("KometShare", isDirectory: true).path
      }
    case "donateShareContact":
      guard let arguments = call.arguments as? [String: Any],
            let accountID = arguments["accountId"] as? String,
            let chatID = arguments["chatId"] as? String,
            let title = arguments["title"] as? String else {
        result(FlutterError(code: "INVALID_SHARE_ACCOUNT", message: "Missing donation arguments", details: nil))
        return
      }
      DispatchQueue.main.async {
        KometShareSuggestions.donate(
          accountID: accountID,
          chatID: chatID,
          chatTitle: title
        )
        result(nil)
      }
    case "clearCache":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func importDocument(_ url: URL, onError: @escaping (Error) -> Void) {
    let scoped = url.startAccessingSecurityScopedResource()
    queue.async {
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      do {
        _ = try self.sharedStore().importDocument(documentURL: url)
        DispatchQueue.main.async { self.sink?(["changed": true]) }
      } catch {
        DispatchQueue.main.async { onError(error) }
      }
    }
  }

  private func sharedStore() throws -> KometShareStore {
    if let store = store { return store }
    let store: KometShareStore
    if extensionEnabled {
      store = try KometShareStore()
    } else {
      let container = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      store = try KometShareStore(containerURL: container)
    }
    self.store = store
    return store
  }

  private func perform(_ result: @escaping FlutterResult,
                       _ action: @escaping (KometShareStore) throws -> Any?) {
    queue.async {
      do {
        let value = try action(self.sharedStore())
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "SHARE_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}
