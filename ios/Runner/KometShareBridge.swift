import Flutter
import UIKit

final class KometShareBridge: NSObject, FlutterSceneLifeCycleDelegate {
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
    case "clearCache":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func scene(_ scene: UIScene,
             willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    guard let contexts = connectionOptions?.urlContexts else { return false }
    return importDocuments(contexts, in: scene)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    importDocuments(URLContexts, in: scene)
  }

  private func importDocuments(_ contexts: Set<UIOpenURLContext>, in scene: UIScene) -> Bool {
    let documents = contexts.map(\.url).filter(\.isFileURL)
    for url in documents {
      importDocument(url) { [weak scene] error in
        guard let window = (scene as? UIWindowScene)?.keyWindow,
              var controller = window.rootViewController else { return }
        while let presented = controller.presentedViewController { controller = presented }
        let alert = UIAlertController(title: "Не удалось открыть файл",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        controller.present(alert, animated: true)
      }
    }
    return !documents.isEmpty
  }

  private func importDocument(_ url: URL, onError: @escaping (Error) -> Void) {
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
