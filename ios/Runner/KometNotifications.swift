import Flutter
import UIKit
import UserNotifications

final class KometNotifications: NSObject {
  static let shared = KometNotifications()

  private static let chatKeys = ["komet_chat", "chatId", "chat_id"]
  static let categoryMessage = "komet_message"
  static let actionReply = "komet_reply"
  static let defaultPushProxyURL = "https://push.komet.purpline.online:18029"

  private var sink: FlutterEventSink?
  private var pendingChatId: Int64 = 0
  private var activeChatId: Int64 = 0

  private var methodChannel: FlutterMethodChannel?
  private var pendingPushToken: String?
  private var apnsToken: String?
  private var pushProxyURL: String?
  private var replyCompletion: (() -> Void)?
  private var replyTimer: DispatchSourceTimer?

  func start() {
    UNUserNotificationCenter.current().delegate = self
    registerCategories()
    requestAuthorization()
  }

  private func registerCategories() {
    let reply = UNTextInputNotificationAction(
      identifier: Self.actionReply,
      title: "Ответить",
      options: [],
      textInputButtonTitle: "Отправить",
      textInputPlaceholder: "Сообщение…"
    )
    // #***! message-интент в категории + NSUserActivityTypes в Info.plist —
    // без пары система не считает уведомления коммуникационными;
    // значение совпадает с константой INSendMessageIntentIdentifier
    let category = UNNotificationCategory(
      identifier: Self.categoryMessage,
      actions: [reply],
      intentIdentifiers: ["INSendMessageIntent"],
      options: [.customDismissAction]
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  func setChannel(_ channel: FlutterMethodChannel) {
    methodChannel = channel
    if let token = pendingPushToken {
      channel.invokeMethod("onPushToken", arguments: token)
    }
  }

  private func requestAuthorization() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  // #***! сброс застрявшего Unregistered: гасим токен и регистрируемся заново
  func reregister() {
    NSLog("KometNotifications: перерегистрация APNs (unregister → register)")
    UIApplication.shared.unregisterForRemoteNotifications()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      UIApplication.shared.registerForRemoteNotifications()
    }
  }

  func didReceivePushToken(_ data: Data) {
    let token = data.map { String(format: "%02x", $0) }.joined()
    NSLog("KometNotifications: APNs токен обновлён (%@…, длина %d)", String(token.prefix(16)), token.count)
    pendingPushToken = token
    apnsToken = token
    methodChannel?.invokeMethod("onPushToken", arguments: token)
  }

  func didFailToRegister(_ error: Error) {
    NSLog("KometNotifications: регистрация APNs не удалась: %@", error.localizedDescription)
    methodChannel?.invokeMethod("onPushTokenError", arguments: error.localizedDescription)
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
    case "consumePushToken":
      result(pendingPushToken)
    case "setBadge":
      var n = 0
      if let num = call.arguments as? NSNumber { n = num.intValue }
      else if let i = call.arguments as? Int { n = i }
      setBadge(n)
      result(nil)
    case "setPushProxyUrl":
      if let args = call.arguments as? [String: Any], let url = args["url"] as? String {
        pushProxyURL = url
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func setBadge(_ count: Int) {
    let center = UNUserNotificationCenter.current()
    if #available(iOS 16.0, *) {
      center.setBadgeCount(count) { _ in }
    } else {
      DispatchQueue.main.async { UIApplication.shared.applicationIconBadgeNumber = count }
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

  func finishReply() {
    replyTimer?.cancel()
    replyTimer = nil
    let completion = replyCompletion
    replyCompletion = nil
    completion?()
  }

  // #***! сброс входящего звонка: ws2 hangup REJECTED через push-сервер
  func postCallDecline(conversationId: String) {
    guard let urlStr = pushProxyURL?.isEmpty == false ? pushProxyURL : Self.defaultPushProxyURL,
          let base = URL(string: urlStr)
    else {
      return
    }
    guard let body = try? JSONSerialization.data(withJSONObject: [
      "conversation_id": conversationId,
    ]) else {
      return
    }
    var request = URLRequest(url: base.appendingPathComponent("call/decline"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    request.timeoutInterval = 20
    let session = URLSession(
      configuration: .ephemeral,
      delegate: KometPushProxyTrust(expectedHost: base.host),
      delegateQueue: nil,
    )
    session.dataTask(with: request).resume()
  }

  private func scheduleReplyTimeout() {
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + .seconds(25))
    timer.setEventHandler { [weak self] in
      self?.finishReply()
    }
    timer.resume()
    replyTimer?.cancel()
    replyTimer = timer
  }

  /// Отправляет ответ через push-сервер, который использует уже установленную
  /// MAX-сессию аккаунта. Не создаёт вторую сессию и не открывает приложение.
  private func sendReply(chatId: Int64, text: String, replyTo: Int64, mark: Int64, accountId: Int64) {
    guard let urlStr = pushProxyURL?.isEmpty == false ? pushProxyURL : Self.defaultPushProxyURL,
          let token = apnsToken, !token.isEmpty,
          accountId > 0,
          let base = URL(string: urlStr)
    else {
      finishReply()
      return
    }
    var payload: [String: Any] = [
      "apns_token": token,
      "account_id": NSNumber(value: accountId),
      "chat_id": NSNumber(value: chatId),
      "text": text,
    ]
    if replyTo > 0 {
      payload["reply_to"] = NSNumber(value: replyTo)
    }
    if mark > 0 {
      payload["mark"] = NSNumber(value: mark)
    }
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
      finishReply()
      return
    }
    var request = URLRequest(url: base.appendingPathComponent("reply"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    request.timeoutInterval = 20
    let session = URLSession(
      configuration: .ephemeral,
      delegate: KometPushProxyTrust(expectedHost: base.host),
      delegateQueue: nil,
    )
    let task = session.dataTask(with: request) { [weak self] _, _, _ in
      DispatchQueue.main.async { self?.finishReply() }
    }
    task.resume()
  }

  private func dismissDelivered(chatId: Int64) {
    guard chatId > 0 else { return }
    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { delivered in
      let identifiers = delivered
        .filter { Self.chatId(fromContent: $0.request.content) == chatId }
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

  private static func chatId(fromContent content: UNNotificationContent) -> Int64 {
    let id = chatId(from: content.userInfo)
    if id > 0 { return id }
    return Int64(content.threadIdentifier) ?? 0
  }

  private static func accountId(fromContent content: UNNotificationContent) -> Int64 {
    if let s = content.userInfo["komet-account-id"] as? String { return Int64(s) ?? 0 }
    if let n = content.userInfo["komet-account-id"] as? NSNumber { return n.int64Value }
    return 0
  }

  private static func optionalChatId(_ raw: Any) -> Int64? {
    if let number = raw as? NSNumber { return number.int64Value }
    if let text = raw as? String { return Int64(text) }
    return nil
  }

  private static func replyTo(fromContent content: UNNotificationContent) -> Int64 {
    if let s = content.userInfo["komet-msg-id"] as? String { return Int64(s) ?? 0 }
    if let n = content.userInfo["komet-msg-id"] as? NSNumber { return n.int64Value }
    return 0
  }

  private static func msgMark(fromContent content: UNNotificationContent) -> Int64 {
    if let s = content.userInfo["komet-msg-time"] as? String { return Int64(s) ?? 0 }
    if let n = content.userInfo["komet-msg-time"] as? NSNumber { return n.int64Value }
    return 0
  }
}

extension KometNotifications: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let chatId = Self.chatId(fromContent: notification.request.content)
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
    let content = response.notification.request.content
    let chatId = Self.chatId(fromContent: content)
    if let textResponse = response as? UNTextInputNotificationResponse,
       response.actionIdentifier == Self.actionReply {
      let text = textResponse.userText.trimmingCharacters(in: .whitespacesAndNewlines)
      replyCompletion = completionHandler
      scheduleReplyTimeout()
      sendReply(
        chatId: chatId,
        text: text,
        replyTo: Self.replyTo(fromContent: content),
        mark: Self.msgMark(fromContent: content),
        accountId: Self.accountId(fromContent: content)
      )
    } else {
      deliver(chatId: chatId)
      completionHandler()
    }
  }
}

/// Принимает TLS-сертификат push-сервера для его хоста (push-сервер использует
/// собственный CA, как и Flutter-fallback через host-pinning).
final class KometPushProxyTrust: NSObject, URLSessionDelegate {
  private let expectedHost: String?

  init(expectedHost: String? = nil) {
    self.expectedHost = expectedHost
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard let trust = challenge.protectionSpace.serverTrust else {
      completionHandler(.performDefaultHandling, nil)
      return
    }
    let host = challenge.protectionSpace.host
    if expectedHost == nil || host == expectedHost {
      completionHandler(.useCredential, URLCredential(trust: trust))
    } else {
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }
}