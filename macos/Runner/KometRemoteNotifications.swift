import AppKit
import FlutterMacOS
import UserNotifications

final class KometRemoteNotifications: NSObject, UNUserNotificationCenterDelegate {
  static let shared = KometRemoteNotifications()

  static let chatKeys = ["komet_chat", "chatId", "chat_id"]
  static let categoryMessage = "komet_message"
  static let actionReply = "komet_reply"
  static let defaultPushProxyURL = "https://push.komet.purpline.online:18029"

  private var channel: FlutterMethodChannel?
  private var eventSink: FlutterEventSink?
  private var pendingPushToken: String?
  private var apnsToken: String?
  private var pushProxyURL: String?
  private var activeChatId = 0

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "ru.komet.app/notifications", binaryMessenger: messenger)
    shared.channel = channel
    channel.setMethodCallHandler { call, result in
      shared.handle(call, result: result)
    }

    let events = FlutterEventChannel(
      name: "ru.komet.app/notification_events", binaryMessenger: messenger)
    events.setStreamHandler(shared)

    UNUserNotificationCenter.current().delegate = shared
  }

  // #***! авторизация и APNs-регистрация ждут полного запуска приложения:
  // requestAuthorization из awakeFromNib падает с «not allowed» не доходя до
  // пользовательского диалога
  func activate() {
    let center = UNUserNotificationCenter.current()
    registerCategories()
    center.requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { granted, error in
      if let error = error {
        NSLog("KometNotifications: авторизация уведомлений не удалась: %@", "\(error)")
      } else {
        NSLog("KometNotifications: авторизация уведомлений: granted=%@", granted ? "YES" : "NO")
      }
      center.getNotificationSettings { settings in
        NSLog(
          "KometNotifications: settings status=%ld alert=%ld sound=%ld badge=%ld",
          settings.authorizationStatus.rawValue,
          settings.alertSetting.rawValue,
          settings.soundSetting.rawValue,
          settings.badgeSetting.rawValue
        )
      }
    }
    DispatchQueue.main.async {
      NSApplication.shared.registerForRemoteNotifications()
    }
  }

  private func registerCategories() {
    var actions: [UNNotificationAction] = []
    if #available(macOS 13.0, *) {
      actions = [
        UNTextInputNotificationAction(
          identifier: Self.actionReply,
          title: "Ответить",
          options: [],
          textInputButtonTitle: "Отправить",
          textInputPlaceholder: "Сообщение…"
        )
      ]
    }
    // #***! message-интент в категории + NSUserActivityTypes в Info.plist — без
    // этой пары система не считает уведомления коммуникационными (macOS их не
    // фильтрует по режимам фокусировки и не показывает sender/аватар).
    // Константа INSendMessageIntentIdentifier в Intents недоступна на macOS,
    // но системная она строка — «INSendMessageIntent» (имя класса интента)
    let category = UNNotificationCategory(
      identifier: Self.categoryMessage,
      actions: actions,
      intentIdentifiers: ["INSendMessageIntent"],
      options: [.customDismissAction]
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
    UNUserNotificationCenter.current().getNotificationCategories { categories in
      NSLog(
        "KometNotifications: категории уведомлений: %@",
        categories.map { "\($0.identifier)(\($0.actions.count))" }.joined(separator: ", ")
      )
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "consumePushToken":
      result(pendingPushToken)
    case "reregisterApns":
      reregister()
      result(nil)
    case "consumeVoipToken", "consumeInitialChat":
      result(nil)
    case "requestVoipRegistration", "clearCache":
      result(nil)
    case "setBadge":
      let count = (call.arguments as? NSNumber)?.intValue ?? 0
      NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
      result(nil)
    case "setPushProxyUrl":
      if let args = call.arguments as? [String: Any], let url = args["url"] as? String {
        pushProxyURL = url
      }
      result(nil)
    case "setActiveChat":
      activeChatId = (call.arguments as? [String: Any])?["chatId"] as? Int ?? 0
      dismissDelivered(chatId: activeChatId)
      result(nil)
    case "clearActiveChat":
      activeChatId = 0
      result(nil)
    case "notifiedChats":
      result([Int]())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func pushToken(_ deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    NSLog(
      "KometNotifications: APNs токен обновлён (%@…, длина %d)",
      String(token.prefix(16)),
      token.count
    )
    pendingPushToken = token
    apnsToken = token
    channel?.invokeMethod("onPushToken", arguments: token)
  }

  func pushTokenFailed(_ error: Error) {
    NSLog("KometNotifications: регистрация APNs не удалась: %@", error.localizedDescription)
    channel?.invokeMethod("onPushTokenError", arguments: error.localizedDescription)
  }

  // #***! сброс застрявшего Unregistered: гасим токен и регистрируемся заново
  private func reregister() {
    NSLog("KometNotifications: перерегистрация APNs (unregister → register)")
    NSApplication.shared.unregisterForRemoteNotifications()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      NSApplication.shared.registerForRemoteNotifications()
    }
  }

  // #***! silent-push (badge/mark-read) системой не показывается — зеркалим
  // локальным уведомлением; alert-push с mutable-content мутирует NSE
  func remoteNotification(_ userInfo: [AnyHashable: Any]) {
    guard let aps = userInfo["aps"] as? [String: Any] else { return }
    guard aps["alert"] == nil else { return }
    let chatId = Self.chatId(in: userInfo)
    guard chatId == 0 || chatId != activeChatId else { return }

    let content = UNMutableNotificationContent()
    content.title = (userInfo["title"] as? String) ?? "Komet"
    content.body = (userInfo["body"] as? String) ?? ""
    content.userInfo = userInfo
    content.sound = .default
    if !content.body.isEmpty {
      content.categoryIdentifier = Self.categoryMessage
    }
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(
        identifier: "komet.silent.\(UUID().uuidString)",
        content: content,
        trigger: nil
      )
    )
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let content = notification.request.content
    if content.userInfo["komet-mirrored"] as? Bool == true {
      completionHandler([.banner, .sound])
      return
    }
    let chatId = Self.chatId(fromContent: content)
    if chatId > 0, chatId == activeChatId {
      completionHandler([])
      return
    }
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let content = response.notification.request.content
    NSLog(
      "KometNotifications: tap: action=%@ category=%@ chat=%@",
      response.actionIdentifier,
      content.categoryIdentifier,
      content.threadIdentifier
    )
    if #available(macOS 13.0, *),
       let textResponse = response as? UNTextInputNotificationResponse,
       response.actionIdentifier == Self.actionReply {
      let text = textResponse.userText.trimmingCharacters(in: .whitespacesAndNewlines)
      let chatId = Self.chatId(fromContent: content)
      sendReply(
        chatId: chatId,
        text: text,
        replyTo: Self.replyTo(fromContent: content),
        mark: Self.msgMark(fromContent: content),
        accountId: Self.accountId(fromContent: content)
      )
      dismissDelivered(chatId: chatId)
      completionHandler()
      return
    }
    let chatId = Self.chatId(in: content.userInfo)
    if chatId > 0 {
      eventSink?(chatId)
    }
    completionHandler()
  }

  private static func chatId(in userInfo: [AnyHashable: Any]) -> Int {
    for key in chatKeys {
      if let value = userInfo[key] as? Int {
        return value
      }
      if let text = userInfo[key] as? String, let value = Int(text) {
        return value
      }
      if let number = userInfo[key] as? NSNumber {
        return number.intValue
      }
    }
    return 0
  }

  private static func chatId(fromContent content: UNNotificationContent) -> Int {
    let id = chatId(in: content.userInfo)
    if id > 0 { return id }
    return Int(content.threadIdentifier) ?? 0
  }

  private static func accountId(fromContent content: UNNotificationContent) -> Int64 {
    if let s = content.userInfo["komet-account-id"] as? String { return Int64(s) ?? 0 }
    if let n = content.userInfo["komet-account-id"] as? NSNumber { return n.int64Value }
    return 0
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

  // #***! ответ из уведомления уезжает через push-сервер, который шлёт его
  // своей MAX-сессией; тап открывает чат через Dart
  private func sendReply(chatId: Int, text: String, replyTo: Int64, mark: Int64, accountId: Int64) {
    guard let urlStr = pushProxyURL?.isEmpty == false ? pushProxyURL : Self.defaultPushProxyURL,
          let token = apnsToken, !token.isEmpty,
          accountId > 0,
          let base = URL(string: urlStr)
    else {
      return
    }
    var payload: [String: Any] = [
      "apns_token": token,
      "account_id": NSNumber(value: accountId),
      "chat_id": NSNumber(value: chatId),
      "text": text,
    ]
    if replyTo > 0 { payload["reply_to"] = NSNumber(value: replyTo) }
    if mark > 0 { payload["mark"] = NSNumber(value: mark) }
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
    var request = URLRequest(url: base.appendingPathComponent("reply"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    request.timeoutInterval = 20
    let session = URLSession(
      configuration: .ephemeral,
      delegate: KometPushProxyTrust(expectedHost: base.host),
      delegateQueue: nil
    )
    let task = session.dataTask(with: request) { _, _, _ in
      session.finishTasksAndInvalidate()
    }
    task.resume()
    dismissDelivered(chatId: chatId)
  }

  private func dismissDelivered(chatId: Int) {
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

  // #***! push-сервер использует собственный CA, как Flutter-fallback host-pinning
  private final class KometPushProxyTrust: NSObject, URLSessionDelegate {
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
}

extension KometRemoteNotifications: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink: @escaping FlutterEventSink
  ) -> FlutterError? {
    self.eventSink = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}