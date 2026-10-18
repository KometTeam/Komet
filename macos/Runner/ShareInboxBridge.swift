import Foundation
import FlutterMacOS

final class ShareInboxBridge {
  private let queue = DispatchQueue(label: "ru.komet.app.share")
  private var store: KometShareStore?

  static func register(messenger: FlutterBinaryMessenger) {
    let bridge = ShareInboxBridge()
    let channel = FlutterMethodChannel(
      name: "ru.komet.app/share", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "consumeInitialShare":
      perform(result) { try $0.nextPayload() }
    case "acknowledgeShare":
      guard let id = (call.arguments as? [String: Any])?["id"] as? String else {
        result(FlutterError(code: "INVALID_SHARE", message: "Missing share ID", details: nil))
        return
      }
      perform(result) { try $0.acknowledge(id: id) }
    case "releaseShare":
      guard let id = (call.arguments as? [String: Any])?["id"] as? String else {
        result(FlutterError(code: "INVALID_SHARE", message: "Missing share ID", details: nil))
        return
      }
      perform(result) { try $0.removeCompleted(id: id) }
    case "clearCache":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func perform(
    _ result: @escaping FlutterResult,
    _ action: @escaping (KometShareStore) throws -> Any?
  ) {
    queue.async {
      do {
        if self.store == nil {
          self.store = try KometShareStore()
        }
        guard let store = self.store else {
          result(nil)
          return
        }
        result(try action(store))
      } catch {
        result(FlutterError(
          code: "SHARE_ERROR",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }
}