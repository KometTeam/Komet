import Foundation

private final class SyntheticCredentialStorage: KometShareCredentialStorage {
  var values: [String: Data] = [:]

  func read(accountID: String) throws -> Data {
    guard let value = values[accountID] else { throw KometShareError.invalidRequest }
    return value
  }

  func write(_ data: Data, accountID: String) throws { values[accountID] = data }

  func remove(accountID: String?) throws {
    if let accountID = accountID { values.removeValue(forKey: accountID) } else { values.removeAll() }
  }
}

@main
struct KometShareAccountsTests {
  static func main() throws {
    let manager = FileManager.default
    let container = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? manager.removeItem(at: container) }
    let storage = SyntheticCredentialStorage()
    let accounts = try KometShareAccounts(containerURL: container, credentialStore: storage)
    let reopened = try KometShareAccounts(containerURL: container, credentialStore: storage)
    try expect(accounts.accounts().isEmpty, "First launch has no account snapshot")
    var input: [String: Any] = [
      "accountId": "12", "accountName": "Synthetic account", "token": "synthetic-source-token",
      "session": ["proxy": "synthetic-secret-proxy"], "login": ["exp": ["synthetic": ["$bin": "AA=="]]],
      "chats": [["id": "34", "title": "Synthetic chat", "type": "DIALOG", "disabledReason": "Encrypted"]]
    ]
    try accounts.sync(input)
    try expect(reopened.accounts().first?.chats.first?.disabledReason == "Encrypted", "Disabled recipients must persist across processes")
    try expectThrows { _ = try reopened.authorizedCredentials(accountID: "12", chatID: "34") }
    try expectThrows { _ = try reopened.authorizedCredentials(accountID: "12", chatID: "999") }
    input["chats"] = [["id": "34", "title": "Synthetic chat", "type": "DIALOG"]]
    try accounts.sync(input)
    try expect(reopened.authorizedCredentials(accountID: "12", chatID: "34")["account_id"] as? String == "12", "Allowed recipient and credentials must be read in one transaction")
    let snapshot = try String(contentsOf: container.appendingPathComponent("KometShare/accounts.json"), encoding: .utf8)
    try expect(!snapshot.contains("synthetic-source-token") && !snapshot.contains("synthetic-secret-proxy"), "Credentials must never enter the shared snapshot")
    try accounts.updateToken(accountID: "12", previousToken: "synthetic-source-token", refreshedToken: "synthetic-renewed-token")
    try expect(reopened.refreshedToken(accountID: "12", knownToken: "synthetic-source-token") == "synthetic-renewed-token", "Host must retrieve renewal for its matching baseline")
    try expect(reopened.refreshedToken(accountID: "12", knownToken: "unrelated-token") == nil, "Renewal must not overwrite another login")
    try reopened.sync(input)
    try expect(accounts.credentials(accountID: "12")["token"] as? String == "synthetic-renewed-token", "Stale baseline export must not replace a renewed token")
    input["token"] = "synthetic-fresh-login"
    try reopened.sync(input)
    try accounts.updateToken(accountID: "12", previousToken: "synthetic-renewed-token", refreshedToken: "synthetic-stale-renewal")
    try expect(accounts.credentials(accountID: "12")["token"] as? String == "synthetic-fresh-login", "Delayed refresh must preserve a new login token")
    input["accountId"] = "56"
    input["accountName"] = "Second synthetic account"
    try accounts.sync(input)
    try expect(reopened.accounts().count == 2, "Multiple account snapshots must coexist")
    try reopened.clear(accountID: "12")
    do {
      try accounts.updateToken(accountID: "12", previousToken: "synthetic-fresh-login", refreshedToken: "late-token")
      throw Failure(message: "Removed accounts must reject token renewal")
    } catch is KometShareError {}
    try expect(storage.values["12"] == nil, "Token renewal must never resurrect a logged out account")
    try expect(accounts.accounts().map { $0.id } == ["56"], "Account-specific logout must preserve other accounts")
    try accounts.clear(accountID: nil)
    try expect(reopened.accounts().isEmpty && storage.values.isEmpty, "Logout all must clear credentials and snapshots")
    print("KometShareAccounts: all tests passed")
  }

  static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw Failure(message: message) }
  }

  static func expectThrows(_ action: () throws -> Void) throws {
    do { try action() } catch { return }
    throw Failure(message: "Expected a disabled or missing recipient to reject authorization")
  }

  struct Failure: Error { let message: String }
}
