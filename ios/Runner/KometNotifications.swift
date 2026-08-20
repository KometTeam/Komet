import Flutter
import UIKit
import UserNotifications

final class KometNotifications: NSObject {
  static let shared = KometNotifications()

  private static let chatKeys = ["komet_chat", "chatId", "chat_id"]

  private var sink: FlutterEventSink?
  private var pendingChatId: Int64 = 0
  private var activeChatId: Int64 = 0

  func start() {
    UNUserNotificationCenter.current().delegate = self
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "consumeInitialChat":
      let chatId = pendingChatId
      pendingChatId = 0
      result(chatId > 0 ? NSNumber(value: chatId) : nil)
    case "setActiveChat":
      activeChatId = Self.chatId(from: call.arguments)
      dismissDelivered(chatId: activeChatId)
      result(nil)
    case "clearActiveChat":
      activeChatId = 0
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func attach(_ sink: FlutterEventSink?) {
    self.sink = sink
  }

  func deliver(chatId: Int64) {
    guard chatId > 0 else { return }
    if let sink = sink {
      sink(NSNumber(value: chatId))
    } else {
      pendingChatId = chatId
    }
  }

  private func dismissDelivered(chatId: Int64) {
    guard chatId > 0 else { return }
    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { delivered in
      let identifiers = delivered
        .filter { Self.chatId(from: $0.request.content.userInfo) == chatId }
        .map { $0.request.identifier }
      guard !identifiers.isEmpty else { return }
      center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
  }

  private static func chatId(from raw: Any?) -> Int64 {
    if let number = raw as? NSNumber { return number.int64Value }
    if let text = raw as? String { return Int64(text) ?? 0 }
    if let map = raw as? [AnyHashable: Any] {
      for key in chatKeys {
        if let value = map[key], let parsed = optionalChatId(value) { return parsed }
      }
    }
    return 0
  }

  private static func optionalChatId(_ raw: Any) -> Int64? {
    if let number = raw as? NSNumber { return number.int64Value }
    if let text = raw as? String { return Int64(text) }
    return nil
  }
}

extension KometNotifications: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let chatId = Self.chatId(from: notification.request.content.userInfo)
    if chatId > 0, chatId == activeChatId {
      completionHandler([])
      return
    }
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    deliver(chatId: Self.chatId(from: response.notification.request.content.userInfo))
    completionHandler()
  }
}
