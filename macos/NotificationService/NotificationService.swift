import AppKit
import Intents
import UserNotifications

// #***! мутация push-уведомлений с mutable-content на macOS: аватар сендера /
// чата, вложение медиа, letter-avatar в акцентных цветах, communication-интент —
// паритет с ios/NotificationService
final class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    guard let base = request.content.mutableCopy() as? UNMutableNotificationContent else {
      contentHandler(request.content)
      return
    }
    bestAttemptContent = base
    let payload = request.content.userInfo
    DispatchQueue.global(qos: .userInitiated).async {
      contentHandler(self.decorate(content: base, payload: payload))
    }
  }

  override func serviceExtensionTimeWillExpire() {
    if let bestAttemptContent = bestAttemptContent, let handler = contentHandler {
      contentHandler = nil
      handler(bestAttemptContent)
    }
  }

  private func decorate(
    content: UNMutableNotificationContent,
    payload: [AnyHashable: Any]
  ) -> UNNotificationContent {
    let alert = (payload["aps"] as? [AnyHashable: Any])?["alert"] as? [AnyHashable: Any]
    let body = Self.payloadString(alert?["body"]) ?? content.body
    var title = Self.payloadString(alert?["title"]) ?? "Komet"

    let mediaURL = Self.payloadString(payload["komet-media"])
    let senderAvatarURL = Self.payloadString(payload["komet-avatar"])
    let chatIconURL = Self.payloadString(payload["komet-chat-icon"])
    let senderName = Self.payloadString(payload["komet-sender-name"])
    let senderIdRaw = Self.payloadString(payload["komet-sender-id"])
    let chatName = Self.payloadString(payload["komet-chat-name"])
    let isChannel = payload["komet-is-channel"] as? Bool ?? false
    let isGroup = payload["komet-is-group"] as? Bool ?? false
    let isCall = payload["call"] as? Bool ?? false
    let attribution = Self.payloadString(payload["komet-attribution"]) ?? ""
    let chatId = Self.chatId(in: payload)

    let attributed: (String) -> String = { name in
      attribution.isEmpty || name.isEmpty ? name : "\(name) > \(attribution)"
    }
    var speakableGroupName: INSpeakableString?
    var avatarURL = URL(string: senderAvatarURL ?? "")
    var personId = senderIdRaw ?? ""

    if isCall {
      let callerId = senderIdRaw?.isEmpty == false
        ? senderIdRaw!
        : Self.payloadString(payload["conversationId"]) ?? String(chatId)
      title = attributed(senderName ?? title)
      personId = callerId
    } else if isChannel {
      title = attributed(chatName ?? title)
      avatarURL = chatIconURL.flatMap { URL(string: $0) }
      personId = "channel-\(chatId)"
    } else if isGroup {
      title = attributed(chatName ?? title)
      avatarURL = chatIconURL.flatMap { URL(string: $0) }
      personId = senderIdRaw?.isEmpty == false ? senderIdRaw! : String(chatId)
      if let name = chatName, !name.isEmpty {
        speakableGroupName = INSpeakableString(spokenPhrase: name)
      }
      if let sender = senderName, !sender.isEmpty {
        content.body = "\(sender): \(body)"
      }
    } else {
      title = attributed(senderName ?? title)
      personId = senderIdRaw?.isEmpty == false ? senderIdRaw! : String(chatId)
    }

    content.title = title
    content.body = body
    content.threadIdentifier = isCall ? "call-\(personId)" : String(chatId)
    if #available(macOS 13.0, *), !isChannel && !isCall {
      content.categoryIdentifier = "komet_message"
    }
    if let badge = (payload["aps"] as? [AnyHashable: Any])?["badge"] as? NSNumber {
      content.badge = badge
    }
    content.userInfo = payload
    content.userInfo["chatId"] = chatId
    content.userInfo["komet_chat"] = chatId

    // #***! аватар: https-выкачка с урезанием, иначе letter-avatar в акцентах
    var avatarData: Data?
    if let url = avatarURL, url.scheme == "https",
       let data = Self.fetchData(url: url, timeout: 5),
       let image = NSImage(data: data) {
      avatarData = Self.jpegData(from: image, maxEdge: 256)
    }
    if avatarData == nil {
      let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      avatarData = Self.letterAvatarData(
        name: title,
        background: Self.accent(
          payload,
          key: isDark ? "komet-accent-dark-bg" : "komet-accent-light-bg",
          fallback: NSColor(
            red: isDark ? 0x35 / 255.0 : 0xDF / 255.0,
            green: isDark ? 0x3D / 255.0 : 0xE0 / 255.0,
            blue: isDark ? 0x90 / 255.0 : 0xFF / 255.0,
            alpha: 1
          )
        ),
        foreground: Self.accent(
          payload,
          key: isDark ? "komet-accent-dark-fg" : "komet-accent-light-fg",
          fallback: NSColor(
            red: isDark ? 0xE4 / 255.0 : 0x1B / 255.0,
            green: isDark ? 0xE1 / 255.0 : 0x1B / 255.0,
            blue: isDark ? 0xE9 / 255.0 : 0x21 / 255.0,
            alpha: 1
          )
        )
      )
    }

    // #***! медиа сообщений прикладываем картинкой к баннеру; без медиа вместо
    // него видна аватарка — macOS не всегда рендерит INPerson-картинку из интента
    if let mediaURL = mediaURL, let url = URL(string: mediaURL), url.scheme == "https",
       let mediaData = Self.fetchData(url: url, timeout: 6) {
      let ext = mediaURL.hasSuffix(".png") ? "png" : "jpg"
      if let attachment = Self.attachment(data: mediaData, ext: ext, identifier: "komet-media") {
        content.attachments = [attachment]
      }
    } else if let avatarData = avatarData {
      if let attachment = Self.attachment(data: avatarData, ext: "jpg", identifier: "komet-avatar") {
        content.attachments = [attachment]
      }
    }

    if #available(macOS 12.0, *) {
      let image = avatarData.flatMap { INImage(imageData: $0) }
      let person = INPerson(
        personHandle: INPersonHandle(value: personId, type: .unknown),
        nameComponents: nil,
        displayName: title.isEmpty ? "Komet" : title,
        image: image,
        contactIdentifier: nil,
        customIdentifier: personId
      )
      let intent = INSendMessageIntent(
        recipients: nil,
        outgoingMessageType: .outgoingMessageText,
        content: content.body,
        speakableGroupName: speakableGroupName,
        conversationIdentifier: isCall ? "call-\(personId)" : String(chatId),
        serviceName: nil,
        sender: person,
        attachments: nil
      )
      let interaction = INInteraction(intent: intent, response: nil)
      interaction.direction = INInteractionDirection.incoming
      // #***! ждём donate до 2с — иначе баннер рендерится до регистрации
      // интеракции и теряет person-аватар
      let donated = DispatchSemaphore(value: 0)
      interaction.donate { _ in donated.signal() }
      _ = donated.wait(timeout: .now() + 2)
      if let updated = try? content.updating(from: intent),
         let mutable = updated.mutableCopy() as? UNMutableNotificationContent {
        mutable.attachments = content.attachments
        mutable.sound = content.sound
        if let badge = content.badge { mutable.badge = badge }
        mutable.title = title
        mutable.body = content.body
        mutable.threadIdentifier = content.threadIdentifier
        mutable.categoryIdentifier = content.categoryIdentifier
        mutable.userInfo = content.userInfo
        return mutable
      }
    }
    return content
  }

  private static func payloadString(_ raw: Any?) -> String? {
    if let s = raw as? String, !s.isEmpty { return s }
    return nil
  }

  private static func chatId(in userInfo: [AnyHashable: Any]) -> Int {
    for key in ["komet_chat", "chatId", "chat_id"] {
      if let value = userInfo[key] as? Int { return value }
      if let text = userInfo[key] as? String, let value = Int(text) { return value }
      if let number = userInfo[key] as? NSNumber { return number.intValue }
    }
    return 0
  }

  private static func accent(
    _ payload: [AnyHashable: Any],
    key: String,
    fallback: NSColor
  ) -> NSColor {
    guard var hex = Self.payloadString(payload[key]) else { return fallback }
    if hex.hasPrefix("#") { hex.removeFirst() }
    if hex.count == 6, let rgb = UInt64(hex, radix: 16) {
      return NSColor(
        red: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: 1
      )
    }
    return fallback
  }

  // #***! letter-avatar 256×256 — fallback для сендеров без картинки
  private static func letterAvatarData(
    name: String,
    background: NSColor,
    foreground: NSColor
  ) -> Data? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let letter = String(trimmed.first ?? "?").uppercased()
    let size = NSSize(width: 256, height: 256)
    let image = NSImage(size: size)
    image.lockFocus()
    background.setFill()
    NSRect(origin: .zero, size: size).fill()
    let attrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.boldSystemFont(ofSize: 120),
      .foregroundColor: foreground,
    ]
    let text = letter as NSString
    let textSize = text.size(withAttributes: attrs)
    text.draw(
      at: NSPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
      withAttributes: attrs
    )
    image.unlockFocus()
    return jpegData(from: image, maxEdge: nil)
  }

  private static func jpegData(from image: NSImage, maxEdge: CGFloat? = 256) -> Data? {
    var source = image
    if let maxEdge = maxEdge {
      let edge = max(image.size.width, image.size.height)
      if edge > maxEdge, edge > 0 {
        let scale = maxEdge / edge
        let scaled = NSImage(
          size: NSSize(width: image.size.width * scale, height: image.size.height * scale)
        )
        scaled.lockFocus()
        image.draw(
          in: NSRect(origin: .zero, size: scaled.size),
          from: NSRect(origin: .zero, size: image.size),
          operation: .copy,
          fraction: 1
        )
        scaled.unlockFocus()
        source = scaled
      }
    }
    guard let tiff = source.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff)
    else { return nil }
    return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
  }

  // #***! синхронная выкачка на фоновом потоке с таймаутом
  private static func fetchData(url: URL, timeout: TimeInterval) -> Data? {
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    var result: Data?
    let semaphore = DispatchSemaphore(value: 0)
    let session = URLSession(configuration: .ephemeral)
    session.dataTask(with: request) { data, response, _ in
      if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
        result = data
      }
      semaphore.signal()
    }.resume()
    _ = semaphore.wait(timeout: .now() + timeout + 1)
    session.finishTasksAndInvalidate()
    return result
  }

  private static func attachment(
    data: Data,
    ext: String,
    identifier: String
  ) -> UNNotificationAttachment? {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(ext)
    do {
      try data.write(to: tmp, options: .atomic)
      return try UNNotificationAttachment(identifier: identifier, url: tmp, options: nil)
    } catch {
      try? FileManager.default.removeItem(at: tmp)
      return nil
    }
  }
}