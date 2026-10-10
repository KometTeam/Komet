import Foundation
import Security
import Darwin

struct KometShareChat: Codable {
  let id: String
  let title: String
  let type: String
  let disabledReason: String?
}

struct KometShareAccount: Codable {
  let id: String
  let name: String
  let chats: [KometShareChat]
}

protocol KometShareCredentialStorage {
  func read(accountID: String) throws -> Data
  func write(_ data: Data, accountID: String) throws
  func remove(accountID: String?) throws
}

private final class KometShareKeychain: KometShareCredentialStorage {
  private let group: String
  private let service = "ru.komet.app.share.credentials"

  init(group: String) { self.group = group }

  func read(accountID: String) throws -> Data {
    var query = query(accountID: accountID)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess else { throw error(status) }
    guard let data = item as? Data else { throw KometShareError.invalidRequest }
    return data
  }

  func write(_ data: Data, accountID: String) throws {
    let query = query(accountID: accountID)
    let changes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]
    var status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(query.merging(changes) { _, new in new } as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw error(status) }
  }

  func remove(accountID: String?) throws {
    let status = SecItemDelete(query(accountID: accountID) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw error(status) }
  }

  private func query(accountID: String?) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccessGroup as String: group
    ]
    if let accountID = accountID { query[kSecAttrAccount as String] = accountID }
    return query
  }

  private func error(_ status: OSStatus) -> NSError {
    let message = status == errSecItemNotFound
      ? "Откройте Komet один раз, чтобы обновить список чатов и доступ к аккаунту."
      : "Не удалось получить доступ к аккаунту Komet. Проверьте поддержку общей группы Keychain в подписи приложения."
    return NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
  }
}

final class KometShareAccounts {
  private let snapshotURL: URL
  private let lockURL: URL
  private let credentialStore: KometShareCredentialStorage

  convenience init() throws {
    let group = Bundle.main.object(forInfoDictionaryKey: "KometShareAppGroup") as? String ?? "group.ru.komet.app"
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
      throw KometShareError.unavailableContainer
    }
    try self.init(containerURL: container, credentialStore: KometShareKeychain(group: group))
  }

  init(containerURL: URL, credentialStore: KometShareCredentialStorage) throws {
    let directory = containerURL.appendingPathComponent("KometShare", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    snapshotURL = directory.appendingPathComponent("accounts.json")
    lockURL = directory.appendingPathComponent("accounts.lock")
    self.credentialStore = credentialStore
  }

  func accounts() throws -> [KometShareAccount] {
    try withLock { try readAccounts() }
  }

  func sync(_ arguments: [String: Any]) throws {
    try withLock {
      guard let id = arguments["accountId"] as? String, Int64(id) != nil,
            let token = arguments["token"] as? String, !token.isEmpty,
            let session = arguments["session"] as? [String: Any],
            let login = arguments["login"] as? [String: Any],
            let rawChats = arguments["chats"] as? [[String: Any]] else {
        throw KometShareError.invalidRequest
      }
      let chats = try rawChats.map { raw -> KometShareChat in
        guard let chatID = raw["id"] as? String, Int64(chatID) != nil,
              let title = raw["title"] as? String, !title.isEmpty,
              let type = raw["type"] as? String else { throw KometShareError.invalidRequest }
        return KometShareChat(id: chatID, title: title, type: type, disabledReason: raw["disabledReason"] as? String)
      }
      let existing = try? readCredentials(accountID: id)
      let activeToken = existing?["sourceToken"] as? String == token ? existing?["token"] as? String ?? token : token
      let credentials: [String: Any] = [
        "account_id": id, "token": activeToken, "sourceToken": token, "session": session, "login": login
      ]
      try writeCredentials(credentials, accountID: id)
      var saved = try readAccounts().filter { $0.id != id }
      let name = arguments["accountName"] as? String ?? "Komet"
      saved.insert(KometShareAccount(id: id, name: name, chats: chats), at: 0)
      try writeAccounts(saved)
    }
  }

  func credentials(accountID: String) throws -> [String: Any] {
    try withLock { try readCredentials(accountID: accountID) }
  }

  func authorizedCredentials(accountID: String, chatID: String) throws -> [String: Any] {
    try withLock {
      guard let account = try readAccounts().first(where: { $0.id == accountID }),
            let chat = account.chats.first(where: { $0.id == chatID }), chat.disabledReason == nil else {
        throw NSError(domain: "KometShare", code: 1, userInfo: [
          NSLocalizedDescriptionKey: "Этот чат недоступен для отправки. Обновите список чатов в Komet."
        ])
      }
      return try readCredentials(accountID: accountID)
    }
  }

  func clear(accountID: String?) throws {
    try withLock {
      try credentialStore.remove(accountID: accountID)
      let remaining = try readAccounts().filter { accountID != nil && $0.id != accountID }
      try writeAccounts(remaining)
    }
  }

  func updateToken(accountID: String, previousToken: String, refreshedToken: String) throws {
    guard !refreshedToken.isEmpty else { return }
    try withLock {
      var saved = try readCredentials(accountID: accountID)
      guard saved["token"] as? String == previousToken else { return }
      saved["token"] = refreshedToken
      try writeCredentials(saved, accountID: accountID)
    }
  }

  func refreshedToken(accountID: String, knownToken: String) throws -> String? {
    try withLock {
      let saved = try readCredentials(accountID: accountID)
      guard saved["sourceToken"] as? String == knownToken,
            let token = saved["token"] as? String, !token.isEmpty, token != knownToken else { return nil }
      return token
    }
  }

  private func readCredentials(accountID: String) throws -> [String: Any] {
    let data = try credentialStore.read(accountID: accountID)
    guard let credentials = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          credentials["account_id"] as? String == accountID else { throw KometShareError.invalidRequest }
    return credentials
  }

  private func writeCredentials(_ credentials: [String: Any], accountID: String) throws {
    try credentialStore.write(JSONSerialization.data(withJSONObject: credentials), accountID: accountID)
  }

  private func readAccounts() throws -> [KometShareAccount] {
    guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return [] }
    return try JSONDecoder().decode([KometShareAccount].self, from: Data(contentsOf: snapshotURL))
  }

  private func writeAccounts(_ accounts: [KometShareAccount]) throws {
    var options: Data.WritingOptions = [.atomic]
    #if os(iOS)
    options.insert(.completeFileProtectionUntilFirstUserAuthentication)
    #endif
    try JSONEncoder().encode(accounts).write(to: snapshotURL, options: options)
  }

  private func withLock<T>(_ operation: () throws -> T) throws -> T {
    let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw KometShareError.unavailableContainer }
    defer { Darwin.close(descriptor) }
    guard flock(descriptor, LOCK_EX) == 0 else { throw KometShareError.unavailableContainer }
    defer { flock(descriptor, LOCK_UN) }
    return try operation()
  }
}
