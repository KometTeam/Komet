import Foundation
import Intents
import Network
import UserNotifications
import UIKit

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // #***! звонковые пуши: как сообщения от контакта, тело несёт трубку
        let isCall = content.userInfo["call"] as? Bool ?? false
        if isCall {
            let callSenderId = content.userInfo["komet-sender-id"] as? String
            let callAvatarURL = content.userInfo["komet-avatar"] as? String
            let callSenderName = content.userInfo["komet-sender-name"] as? String
            let callAttribution = content.userInfo["komet-attribution"] as? String ?? ""
            let key = "call-" + (callSenderId?.isEmpty == false ? callSenderId! : conversationIdFallback(content))
            content.threadIdentifier = key
            content.categoryIdentifier = ""
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.buildCommunication(
                    content: content,
                    senderId: callSenderId?.isEmpty == false ? callSenderId! : self?.conversationIdFallback(content) ?? "",
                    senderName: self?.attributed(
                        callSenderName ?? content.title,
                        by: callAttribution
                    ) ?? content.title,
                    chatId: self?.conversationIdFallback(content) ?? "",
                    avatarURL: callAvatarURL.flatMap { URL(string: $0) },
                    avatarCacheKey: key,
                    mediaURL: nil,
                    speakableGroupName: nil
                )
            }
            return
        }

        let mediaURL = content.userInfo["komet-media"] as? String
        let senderAvatarURL = content.userInfo["komet-avatar"] as? String
        let chatIconURL = content.userInfo["komet-chat-icon"] as? String
        let senderName = content.userInfo["komet-sender-name"] as? String
        let senderIdRaw = content.userInfo["komet-sender-id"] as? String
        let chatName = content.userInfo["komet-chat-name"] as? String
        let isChannel = content.userInfo["komet-is-channel"] as? Bool ?? false
        let isGroup = content.userInfo["komet-is-group"] as? Bool ?? false
        let chatId: String = {
            if let s = content.userInfo["chatId"] as? String { return s }
            if let n = content.userInfo["chatId"] as? NSNumber { return n.stringValue }
            if let s = content.userInfo["komet-chat-id"] as? String { return s }
            return content.threadIdentifier
        }()

        let displayName: String
        let avatarURL: URL?
        let personId: String
        var speakableGroupName: INSpeakableString? = nil
        let attribution = content.userInfo["komet-attribution"] as? String ?? ""

        if isChannel {
            displayName = attributed(chatName ?? content.title, by: attribution)
            avatarURL = chatIconURL.flatMap { URL(string: $0) }
            personId = "channel-" + chatId
        } else if isGroup {
            displayName = attributed(chatName ?? content.title, by: attribution)
            avatarURL = chatIconURL.flatMap { URL(string: $0) }
            personId = senderIdRaw.flatMap { $0.isEmpty ? nil : $0 } ?? chatId
            if let name = chatName, !name.isEmpty {
                speakableGroupName = INSpeakableString(spokenPhrase: name)
            }
            if let sn = senderName, !sn.isEmpty {
                content.body = "\(sn): \(content.body)"
            }
        } else {
            displayName = attributed(
                senderName ?? (content.userInfo["komet-name"] as? String) ?? content.title,
                by: attribution
            )
            avatarURL = senderAvatarURL.flatMap { URL(string: $0) }
            personId = senderIdRaw.flatMap { $0.isEmpty ? nil : $0 } ?? chatId
        }

        if !chatId.isEmpty {
            content.threadIdentifier = chatId
        }
        if !isChannel {
            content.categoryIdentifier = KometNotificationCategory.message
        }

        let avatarCacheKey = KometAvatarCache.key(
            isGroup: isGroup,
            isChannel: isChannel,
            chatId: chatId,
            senderId: senderIdRaw
        )
        NSLog("KometNSE: didReceive chat=%@ avatar=%d group=%d channel=%d call=%d", chatId, senderAvatarURL != nil ? 1 : 0, isGroup ? 1 : 0, isChannel ? 1 : 0, isCall ? 1 : 0)
        DispatchQueue.global(qos: .userInitiated).async {
            self.buildCommunication(
                content: content,
                senderId: personId,
                senderName: displayName,
                chatId: chatId,
                avatarURL: avatarURL,
                avatarCacheKey: avatarCacheKey,
                mediaURL: mediaURL,
                speakableGroupName: speakableGroupName
            )
        }
    }

    private func conversationIdFallback(_ content: UNNotificationContent) -> String {
        if let s = content.userInfo["conversationId"] as? String { return s }
        if let s = content.userInfo["komet-chat-id"] as? String { return s }
        return content.threadIdentifier
    }

    private func attributed(_ name: String, by attribution: String) -> String {
        if attribution.isEmpty || name.isEmpty { return name }
        return "\(name) > \(attribution)"
    }

    override func serviceExtensionTimeWillExpire() {
        NSLog("KometNSE: time Will Expire — delivering best attempt")
        if let content = bestAttemptContent {
            deliver(content)
        }
    }

    private func buildCommunication(
        content: UNMutableNotificationContent,
        senderId: String,
        senderName: String,
        chatId: String,
        avatarURL: URL?,
        avatarCacheKey: String,
        mediaURL: String?,
        speakableGroupName: INSpeakableString?
    ) {
        // #***! превью и аватарка качаются параллельно с дедлайном,
        // чтобы extension не истёк и не доставил сырой баннер.
        // Аватар держим в памяти: iOS рендерит person-картинку через
        // INImageService-прокси tmp-файла, и тот опаздывает к рендеру —
        // тогда баннер теряет аватарку (системный лог: "no data found
        // content URL provided"). INImage(namedUIImageImage:) файл не нужен.
        let group = DispatchGroup()
        var avatarImage: UIImage?
        var mediaImg: UIImage?

        group.enter()
        DispatchQueue.global().async { [weak self] in
            defer { group.leave() }
            var cachedFile: URL?
            if let url = avatarURL, url.scheme == "https" {
                cachedFile = KometAvatarCache.shared.file(for: avatarCacheKey, url: url)
                if let cachedFile {
                    avatarImage = UIImage(contentsOfFile: cachedFile.path)
                }
                if avatarImage == nil, let fetched = self?.downloadImage(url: url) {
                    avatarImage = self?.downscale(image: fetched, maxEdge: 256)
                    if let file = self?.downloadToFile(url: url, ext: "jpg") {
                        KometAvatarCache.shared.store(file, for: avatarCacheKey, url: url)
                    }
                }
            }
            if avatarImage == nil {
                let (bg, fg) = self?.avatarColors(from: content) ?? (
                    UIColor(red: 0x35 / 255, green: 0x3D / 255, blue: 0x90 / 255, alpha: 1),
                    UIColor(red: 0xE4 / 255, green: 0xE1 / 255, blue: 0xE9 / 255, alpha: 1)
                )
                avatarImage = self?.renderLetterAvatar(
                    name: senderName,
                    background: bg,
                    foreground: fg
                )
            }
        }

        group.enter()
        DispatchQueue.global().async { [weak self] in
            defer { group.leave() }
            if let media = mediaURL,
               let url = URL(string: media),
               url.scheme == "https",
               let img = self?.downloadImage(url: url)
            {
                mediaImg = img
            }
        }

        _ = group.wait(timeout: .now() + 6)
        NSLog("KometNSE: avatar=%d media=%d", avatarImage != nil ? 1 : 0, mediaImg != nil ? 1 : 0)

        if let media = mediaImg {
            attachImage(media, identifier: "komet-media", content: content)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let image: INImage? = avatarImage?.jpegData(compressionQuality: 0.9)
                .flatMap { INImage(imageData: $0) }
            let person = INPerson(
                personHandle: INPersonHandle(value: senderId, type: .unknown),
                nameComponents: nil,
                displayName: senderName.isEmpty ? "Komet" : senderName,
                image: image,
                contactIdentifier: nil,
                customIdentifier: senderId
            )

            let intent = INSendMessageIntent(
                recipients: nil,
                outgoingMessageType: .outgoingMessageText,
                content: content.body,
                speakableGroupName: speakableGroupName,
                conversationIdentifier: chatId,
                serviceName: nil,
                sender: person,
                attachments: nil
            )

            // #***! история для Siri, доставка не зависит от donate-колбэка:
            // лимиты iOS по donation делали обновление рандомным
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.direction = .incoming
            interaction.donate { _ in }

            var finalContent: UNNotificationContent = content
            do {
                let updated = try content.updating(from: intent)
                if let mutable = updated.mutableCopy() as? UNMutableNotificationContent {
                    mutable.userInfo["chatId"] = chatId
                    mutable.userInfo["komet_chat"] = chatId
                    if let mid = content.userInfo["komet-msg-id"] as? String {
                        mutable.userInfo["komet-msg-id"] = mid
                    } else if let mid = content.userInfo["komet-msg-id"] as? NSNumber {
                        mutable.userInfo["komet-msg-id"] = mid.stringValue
                    }
                    if let mt = content.userInfo["komet-msg-time"] as? String {
                        mutable.userInfo["komet-msg-time"] = mt
                    } else if let mt = content.userInfo["komet-msg-time"] as? NSNumber {
                        mutable.userInfo["komet-msg-time"] = mt.stringValue
                    }
                    mutable.threadIdentifier = chatId
                    if !content.categoryIdentifier.isEmpty {
                        mutable.categoryIdentifier = content.categoryIdentifier
                    }
                    if !content.attachments.isEmpty {
                        mutable.attachments = content.attachments
                    }
                    finalContent = mutable
                }
            } catch {
                finalContent = content
            }
            NSLog("KometNSE: deliver attachments=%d", finalContent.attachments.count)
            self.deliver(finalContent)
        }
    }

    private func attachImage(
        _ image: UIImage,
        identifier: String,
        content: UNMutableNotificationContent
    ) {
        let thumb = downscale(image: image, maxEdge: 256)
        guard let jpeg = thumb.jpegData(compressionQuality: 0.82) else { return }
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        do {
            try jpeg.write(to: tmpURL, options: .atomic)
            let attachment = try UNNotificationAttachment(
                identifier: identifier,
                url: tmpURL,
                options: [
                    UNNotificationAttachmentOptionsThumbnailHiddenKey: false,
                    UNNotificationAttachmentOptionsThumbnailClippingRectKey: CGRect(
                        x: 0, y: 0, width: 1, height: 1
                    ),
                ]
            )
            content.attachments = [attachment]
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }

    private func deliver(_ content: UNNotificationContent) {
        DispatchQueue.main.async { [weak self] in
            guard let handler = self?.contentHandler else { return }
            self?.contentHandler = nil
            handler(content)
        }
    }

    private func downloadImage(url: URL) -> UIImage? {
        guard let data = fetchData(url: url) else { return nil }
        return UIImage(data: data)
    }

    private func downloadToFile(url: URL, ext: String) -> URL? {
        guard let data = fetchData(url: url) else { return nil }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        do {
            try data.write(to: tmp, options: .atomic)
            return tmp
        } catch {
            return nil
        }
    }

    private final class BufferBox {
        var data = Data()
    }

    private func fetchData(url: URL) -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?

        let host = url.host ?? ""
        let port = url.port ?? 443
        let pathQuery = url.path.isEmpty ? "/" : url.path + (url.query.map { "?" + $0 } ?? "")

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let parameters = NWParameters.tls
        let connection = NWConnection(to: endpoint, using: parameters)

        let buffer = BufferBox()
        let queue = DispatchQueue(label: "komet-nse-tcp")

        let timeoutTimer = DispatchSource.makeTimerSource(queue: queue)
        timeoutTimer.schedule(deadline: .now() + .seconds(8))
        timeoutTimer.setEventHandler {
            connection.cancel()
            semaphore.signal()
        }
        timeoutTimer.resume()

        let done: () -> Void = {
            result = Self.extractBody(from: buffer.data)
            timeoutTimer.cancel()
            connection.cancel()
            semaphore.signal()
        }

        connection.stateUpdateHandler = { state in
            if state == .ready {
                let request = "GET \(pathQuery) HTTP/1.1\r\nHost: \(host)\r\nConnection: close\r\nAccept-Encoding: identity\r\n\r\n"
                connection.send(content: Data(request.utf8), completion: .contentProcessed { sendError in
                    if sendError != nil {
                        done()
                    } else {
                        Self.receiveLoop(connection, buffer: buffer, done: done)
                    }
                })
            } else if case .failed = state {
                done()
            }
        }

        connection.start(queue: queue)
        semaphore.wait()
        return result
    }

    private static func receiveLoop(
        _ connection: NWConnection,
        buffer: BufferBox,
        done: @escaping () -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data { buffer.data.append(data) }
            if isComplete || error != nil {
                done()
            } else {
                Self.receiveLoop(connection, buffer: buffer, done: done)
            }
        }
    }

    private static func extractBody(from data: Data) -> Data? {
        let separator: [UInt8] = [0x0D, 0x0A, 0x0D, 0x0A]
        let sepLen = separator.count
        guard data.count > sepLen else { return nil }
        var headerEnd = -1
        for i in 0..<(data.count - sepLen) {
            if data[i] == 0x0D && data[i + 1] == 0x0A && data[i + 2] == 0x0D && data[i + 3] == 0x0A {
                headerEnd = i + sepLen
                break
            }
        }
        guard headerEnd >= 0 else { return nil }
        let body = data.subdata(in: headerEnd..<data.count)
        let headerStr = String(data: data.subdata(in: 0..<headerEnd), encoding: .isoLatin1) ?? ""
        if let contentLength = contentLength(from: headerStr), contentLength >= 0, contentLength <= body.count {
            return body.prefix(contentLength)
        }
        if isChunked(from: headerStr) {
            return decodeChunked(body)
        }
        return body
    }

    private static func contentLength(from header: String) -> Int? {
        guard let range = header.range(of: "Content-Length:", options: .caseInsensitive) else { return nil }
        let after = header[range.upperBound...]
        let endIdx = after.firstIndex(where: { $0 == "\r" || $0 == "\n" }) ?? after.endIndex
        return Int(after[..<endIdx].trimmingCharacters(in: .whitespaces))
    }

    private static func isChunked(from header: String) -> Bool {
        header.range(of: "Transfer-Encoding: chunked", options: .caseInsensitive) != nil
    }

    private static func decodeChunked(_ body: Data) -> Data {
        var result = Data()
        var pos = body.startIndex
        while pos < body.endIndex {
            guard let crlf = findCRLF(in: body, from: pos) else { break }
            let sizeStr = String(data: body.subdata(in: pos..<crlf), encoding: .ascii) ?? ""
            let sizeOnly = sizeStr.split(separator: ";").first ?? ""
            guard let size = Int(sizeOnly.trimmingCharacters(in: .whitespaces), radix: 16) else { break }
            if size == 0 { break }
            let dataStart = crlf + 2
            let dataEnd = body.index(dataStart, offsetBy: size, limitedBy: body.endIndex) ?? body.endIndex
            result.append(body.subdata(in: dataStart..<dataEnd))
            pos = body.index(dataEnd, offsetBy: 2, limitedBy: body.endIndex) ?? body.endIndex
        }
        return result
    }

    private static func findCRLF(in data: Data, from start: Int) -> Int? {
        var i = start
        while i + 1 < data.count {
            if data[i] == 0x0D && data[i + 1] == 0x0A {
                return i
            }
            i += 1
        }
        return nil
    }

    private func downscale(image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let edge = max(size.width, size.height)
        if edge <= maxEdge { return image }
        let scale = maxEdge / edge
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private func renderLetterAvatar(
        name: String,
        background: UIColor,
        foreground: UIColor
    ) -> UIImage {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let letter = String(trimmed.first ?? "?").uppercased()
        let size = CGSize(width: 256, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            background.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 120, weight: .bold),
                .foregroundColor: foreground,
            ]
            let text = letter as NSString
            let textSize = text.size(withAttributes: attrs)
            let origin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: origin, withAttributes: attrs)
        }
    }

    private func avatarColors(from content: UNNotificationContent) -> (UIColor, UIColor) {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let bgKey = isDark ? "komet-accent-dark-bg" : "komet-accent-light-bg"
        let fgKey = isDark ? "komet-accent-dark-fg" : "komet-accent-light-fg"
        let defaultBg = isDark
            ? UIColor(red: 0x35 / 255, green: 0x3D / 255, blue: 0x90 / 255, alpha: 1)
            : UIColor(red: 0xDF / 255, green: 0xE0 / 255, blue: 0xFF / 255, alpha: 1)
        let defaultFg = isDark
            ? UIColor(red: 0xE4 / 255, green: 0xE1 / 255, blue: 0xE9 / 255, alpha: 1)
            : UIColor(red: 0x1B / 255, green: 0x1B / 255, blue: 0x21 / 255, alpha: 1)
        let bg = color(from: content.userInfo[bgKey] as? String) ?? defaultBg
        let fg = color(from: content.userInfo[fgKey] as? String) ?? defaultFg
        return (bg, fg)
    }

    private func color(from hex: String?) -> UIColor? {
        guard var hex = hex, !hex.isEmpty else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb), hex.count == 6 else { return nil }
        return UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum KometNotificationCategory {
    static let message = "komet_message"
}

/// Локальный кеш аватарок для уведомлений, ключённый по chatID/userID.
/// Хранит соответствие идентификатор → (URL, файл). Если URL не изменился —
/// используется закешированный файл вместо повторной загрузки из сети.
/// При смене аватарки (новый URL) кеш обновляется автоматически.
final class KometAvatarCache {
    static let shared = KometAvatarCache()

    private struct Entry {
        let url: String
        let file: String
    }

    private let queue = DispatchQueue(label: "komet.komet-avatar-cache")
    private var entries: [String: Entry] = [:]
    private let manifestURL: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = caches.appendingPathComponent("komet-avatar-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        manifestURL = dir.appendingPathComponent("manifest.json")
        loadManifest()
    }

    static func key(isGroup: Bool, isChannel: Bool, chatId: String, senderId: String?) -> String {
        if isGroup || isChannel {
            return "chat:\(chatId)"
        }
        if let sid = senderId, !sid.isEmpty {
            return "user:\(sid)"
        }
        return "chat:\(chatId)"
    }

    /// Возвращает закешированный файл, если URL совпадает с ранее сохранённым.
    /// Если URL изменился — инвалидирует запись и возвращает nil (вынуждая
    /// повторную загрузку и обновление кеша через `store`).
    func file(for key: String, url: URL) -> URL? {
        let urlStr = url.absoluteString
        var result: URL?
        queue.sync {
            guard let entry = entries[key], entry.url == urlStr else {
                if let stale = entries[key] {
                    entries.removeValue(forKey: key)
                    try? FileManager.default.removeItem(atPath: stale.file)
                    persistManifest()
                }
                return
            }
            let fileURL = URL(fileURLWithPath: entry.file)
            if FileManager.default.fileExists(atPath: entry.file) {
                result = fileURL
            } else {
                entries.removeValue(forKey: key)
                persistManifest()
            }
        }
        return result
    }

    /// Сохраняет скачанный файл в кеш и обновляет манифест. Файл копируется в
    /// dedicated-директорию кеша с картиночным расширением — INImage(url:)
    /// требует распознаваемого формата, иначе рендер без аватарки.
    func store(_ source: URL, for key: String, url: URL) {
        let urlStr = url.absoluteString
        let ext = source.pathExtension.isEmpty ? "jpg" : source.pathExtension
        let dest = manifestURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(key.replacingOccurrences(of: "/", with: "_"))")
            .appendingPathExtension(ext)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: source, to: dest)
        } catch {
            return
        }
        queue.sync {
            if let old = entries[key] {
                try? FileManager.default.removeItem(atPath: old.file)
            }
            entries[key] = Entry(url: urlStr, file: dest.path)
            persistManifest()
        }
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        else { return }
        for (key, fields) in raw {
            guard let url = fields["url"], let file = fields["file"] else { continue }
            // кеш версий с не-картиночным расширением не рендерится INImage — выпускаем
            if file.hasSuffix(".bin") {
                try? FileManager.default.removeItem(atPath: file)
                continue
            }
            entries[key] = Entry(url: url, file: file)
        }
    }

    private func persistManifest() {
        var raw: [String: [String: String]] = [:]
        for (key, entry) in entries {
            raw[key] = ["url": entry.url, "file": entry.file]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: raw) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }
}
