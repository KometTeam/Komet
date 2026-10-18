import Intents
import UIKit

enum KometShareSuggestions {
  static func donate(accountID: String, chatID: String, chatTitle: String) {
    guard Int64(accountID) != nil, Int64(chatID) != nil else { return }
    var components = PersonNameComponents()
    components.nickname = chatTitle
    let handle = INPersonHandle(value: "komet-\(chatID)", type: .unknown)
    let image: INImage? = avatarImage(accountID: accountID, chatID: chatID)
      .map { INImage(imageData: $0) }
    let person = INPerson(
      personHandle: handle,
      nameComponents: components,
      displayName: chatTitle,
      image: image,
      contactIdentifier: nil,
      customIdentifier: "ru.komet.chat.\(chatID)"
    )
    let intent = INSendMessageIntent(
      recipients: [person],
      content: nil,
      speakableGroupName: nil,
      conversationIdentifier: "komet-\(chatID)",
      serviceName: "Komet",
      sender: nil
    )
    let interaction = INInteraction(
      intent: intent,
      response: INSendMessageIntentResponse(code: .success, userActivity: nil)
    )
    interaction.groupIdentifier = "ru.komet.app"
    interaction.donate { error in
      if let error {
        NSLog("KometShareSuggestions: donate failed \(error.localizedDescription)")
      }
    }
  }

  private static func avatarImage(accountID: String, chatID: String) -> Data? {
    guard let root = shareRootURL?.appendingPathComponent("avatars/\(accountID)", isDirectory: true),
          let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
          ) else {
      return nil
    }
    let avatar = entries
      .filter { $0.lastPathComponent.hasPrefix("\(chatID)_") }
      .compactMap { url -> (URL, Date)? in
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
          .contentModificationDate ?? .distantPast
        return (url, date)
      }
      .max { $0.1 < $1.1 }?.0
    guard let avatar,
          let data = try? Data(contentsOf: avatar), !data.isEmpty, data.count < 1 << 20 else {
      return nil
    }
    return data
  }

  private static var shareRootURL: URL? {
    let group = Bundle.main.object(forInfoDictionaryKey: "KometShareAppGroup") as? String
      ?? "group.ru.komet.app"
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    else { return nil }
    return container.appendingPathComponent("KometShare", isDirectory: true)
  }
}