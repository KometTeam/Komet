import Intents
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

        let mediaURL = content.userInfo["komet-media"] as? String
        let avatarURL = content.userInfo["komet-avatar"] as? String
        let senderName = content.userInfo["komet-sender-name"] as? String
        let senderId = content.userInfo["komet-sender-id"] as? String
        let chatId = (content.userInfo["chatId"] as? String)
            ?? (content.userInfo["komet-chat-id"] as? String)
            ?? content.threadIdentifier

        if let avatar = avatarURL,
           let url = URL(string: avatar),
           url.scheme == "https",
           let senderId = senderId, !senderId.isEmpty
        {
            Task { await buildCommunication(
                content: content,
                senderId: senderId,
                senderName: senderName ?? "",
                chatId: chatId ?? "",
                avatarURL: url,
                mediaURL: mediaURL
            ) }
            return
        }

        if let media = mediaURL,
           let url = URL(string: media),
           url.scheme == "https"
        {
            if let image = downloadImage(url: url) {
                attachImage(image, identifier: "komet-media", content: content)
            }
            deliver(content)
            return
        }

        let name = (content.userInfo["komet-name"] as? String) ?? content.title
        let (bg, fg) = avatarColors(from: content)
        attachLetterAvatar(name: name, background: bg, foreground: fg, content: content)
    }

    override func serviceExtensionTimeWillExpire() {
        if let content = bestAttemptContent {
            deliver(content)
        }
    }

    private func buildCommunication(
        content: UNMutableNotificationContent,
        senderId: String,
        senderName: String,
        chatId: String,
        avatarURL: URL,
        mediaURL: String?
    ) async {
        let avatarFile = downloadToFile(url: avatarURL, ext: "jpg")
        let image: INImage? = avatarFile.map { INImage(url: $0) }

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
            speakableGroupName: nil,
            conversationIdentifier: chatId,
            serviceName: nil,
            sender: person,
            attachments: nil
        )

        if let media = mediaURL,
           let url = URL(string: media),
           url.scheme == "https",
           let img = downloadImage(url: url)
        {
            attachImage(img, identifier: "komet-media", content: content)
        }

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming

        do {
            try await interaction.donate()
        } catch {
            deliver(content)
            return
        }

        do {
            let updated = try content.updating(from: intent)
            deliver(updated)
        } catch {
            deliver(content)
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

    private func attachLetterAvatar(
        name: String,
        background: UIColor,
        foreground: UIColor,
        content: UNMutableNotificationContent
    ) {
        let image = renderLetterAvatar(
            name: name,
            background: background,
            foreground: foreground
        )
        guard let png = image.pngData() else {
            deliver(content)
            return
        }
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        do {
            try png.write(to: tmpURL, options: .atomic)
            let attachment = try UNNotificationAttachment(
                identifier: "komet-letter",
                url: tmpURL,
                options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false]
            )
            content.attachments = [attachment]
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
        }
        deliver(content)
    }

    private func deliver(_ content: UNNotificationContent) {
        contentHandler?(content)
        contentHandler = nil
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

    private func fetchData(url: URL) -> Data? {
        let session = URLSession(configuration: .ephemeral)
        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?
        let task = session.dataTask(with: url) { data, _, _ in
            result = data
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + .seconds(20))
        task.cancel()
        return result
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