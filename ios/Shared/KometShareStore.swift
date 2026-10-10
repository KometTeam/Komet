import Foundation
#if canImport(MobileCoreServices)
import MobileCoreServices
#else
import CoreServices
#endif

enum KometShareError: LocalizedError {
  case unavailableContainer
  case tooManyAttachments
  case unsupportedAttachment
  case unreadableAttachment
  case emptyRequest
  case invalidRequest

  var errorDescription: String? {
    switch self {
    case .unavailableContainer:
      return "Нет доступа к общему хранилищу Komet. Установите приложение с поддержкой App Groups."
    case .tooManyAttachments:
      return "Можно передать не больше 30 вложений за один раз."
    case .unsupportedAttachment:
      return "Не удалось прочитать одно из вложений. Попробуйте поделиться им как файлом."
    case .unreadableAttachment:
      return "Не удалось скопировать одно из вложений. Проверьте, что файл доступен на устройстве."
    case .emptyRequest:
      return "Не найдено файлов, фотографий или текста для отправки."
    case .invalidRequest:
      return "Не удалось прочитать сохранённые вложения."
    }
  }
}

struct KometSharedFile: Codable {
  let relativePath: String
  let name: String
  let mime: String
  let size: Int64
}

struct KometShareDraft {
  let id: String
  let directoryURL: URL
  let createdAt: TimeInterval
}

struct KometOutgoingShare: Codable {
  let id: String
  let createdAt: TimeInterval
  let accountID: String
  let chatID: String
  let chatTitle: String
  let files: [KometSharedFile]
  let text: String?
  var status: String
  var message: String?
}

final class KometShareStore {
  static let maximumAttachments = 30

  private struct Manifest: Codable {
    let id: String
    let createdAt: TimeInterval
    let files: [KometSharedFile]
    let text: String?
    let subject: String?
  }

  private let manager = FileManager.default
  private let stagingURL: URL
  private let requestsURL: URL
  private let quarantineURL: URL
  private let outgoingURL: URL

  convenience init() throws {
    let configured = Bundle.main.object(forInfoDictionaryKey: "KometShareAppGroup") as? String
    let group = configured?.isEmpty == false ? configured! : "group.ru.komet.app"
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: group
    ) else {
      throw KometShareError.unavailableContainer
    }
    try self.init(containerURL: container)
  }

  init(containerURL: URL) throws {
    let root = containerURL.appendingPathComponent("KometShare", isDirectory: true)
    stagingURL = root.appendingPathComponent("staging", isDirectory: true)
    requestsURL = root.appendingPathComponent("requests", isDirectory: true)
    quarantineURL = root.appendingPathComponent("quarantine", isDirectory: true)
    outgoingURL = root.appendingPathComponent("outgoing", isDirectory: true)
    try manager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
    try manager.createDirectory(at: requestsURL, withIntermediateDirectories: true)
    try manager.createDirectory(at: outgoingURL, withIntermediateDirectories: true)
  }

  func beginRequest() throws -> KometShareDraft {
    let id = UUID().uuidString.lowercased()
    let directory = stagingURL.appendingPathComponent(id, isDirectory: true)
    try manager.createDirectory(
      at: directory.appendingPathComponent("attachments", isDirectory: true),
      withIntermediateDirectories: true
    )
    return KometShareDraft(id: id, directoryURL: directory, createdAt: Date().timeIntervalSince1970)
  }

  func copyFile(
    at source: URL,
    suggestedName: String?,
    typeIdentifier: String?,
    into draft: KometShareDraft
  ) throws -> KometSharedFile {
    guard source.isFileURL else { throw KometShareError.unsupportedAttachment }
    let access = source.startAccessingSecurityScopedResource()
    defer { if access { source.stopAccessingSecurityScopedResource() } }
    var coordinationError: NSError?
    var outcome: Result<KometSharedFile, Error>?
    NSFileCoordinator().coordinate(
      readingItemAt: source,
      options: .withoutChanges,
      error: &coordinationError
    ) { readableURL in
      outcome = Result {
        let values = try readableURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
          throw KometShareError.unsupportedAttachment
        }
        let type = Self.resolvedType(
          typeIdentifier, fileNames: [readableURL.lastPathComponent, suggestedName]
        )
        let name = Self.fileName(suggestedName ?? readableURL.lastPathComponent, typeIdentifier: type)
        let destination = try self.destination(in: draft, name: name)
        do {
          try self.manager.copyItem(at: readableURL, to: destination)
          return try self.fileMetadata(at: destination, name: name, typeIdentifier: type)
        } catch {
          try? self.manager.removeItem(at: destination)
          throw error
        }
      }
    }
    if let error = coordinationError { throw error }
    guard let result = outcome else { throw KometShareError.unreadableAttachment }
    return try result.get()
  }

  func saveData(
    _ data: Data,
    suggestedName: String?,
    typeIdentifier: String,
    into draft: KometShareDraft
  ) throws -> KometSharedFile {
    let typeIdentifier = Self.resolvedType(typeIdentifier, fileNames: [suggestedName])
    let name = Self.fileName(suggestedName ?? "Вложение", typeIdentifier: typeIdentifier)
    let destination = try self.destination(in: draft, name: name)
    do {
      try data.write(to: destination, options: .atomic)
      return try fileMetadata(at: destination, name: name, typeIdentifier: typeIdentifier)
    } catch {
      try? manager.removeItem(at: destination)
      throw error
    }
  }

  @discardableResult
  func commit(
    _ draft: KometShareDraft,
    files: [KometSharedFile],
    text: String?,
    subject: String?
  ) throws -> String {
    guard files.count <= Self.maximumAttachments else { throw KometShareError.tooManyAttachments }
    let text = Self.nonempty(text)
    guard !files.isEmpty || text != nil else { throw KometShareError.emptyRequest }
    let manifest = Manifest(
      id: draft.id,
      createdAt: draft.createdAt,
      files: files,
      text: text,
      subject: Self.nonempty(subject)
    )
    try validate(manifest, at: draft.directoryURL)
    try JSONEncoder().encode(manifest).write(
      to: draft.directoryURL.appendingPathComponent("manifest.json"), options: .atomic
    )
    try writeState("pending", at: draft.directoryURL)
    try manager.moveItem(at: draft.directoryURL, to: requestURL(id: draft.id))
    return draft.id
  }

  func discard(_ draft: KometShareDraft) {
    try? manager.removeItem(at: draft.directoryURL)
  }

  func prepareOutgoing(
    _ draft: KometShareDraft, files: [KometSharedFile], text: String?,
    accountID: String, chatID: String, chatTitle: String
  ) throws -> KometOutgoingShare {
    guard Int64(accountID) != nil, Int64(chatID) != nil else { throw KometShareError.invalidRequest }
    let text = Self.nonempty(text)
    try validate(Manifest(id: draft.id, createdAt: draft.createdAt, files: files, text: text, subject: nil), at: draft.directoryURL)
    let outgoing = KometOutgoingShare(
      id: draft.id, createdAt: draft.createdAt, accountID: accountID, chatID: chatID,
      chatTitle: chatTitle, files: files, text: text, status: "prepared", message: nil
    )
    try writeOutgoing(outgoing, at: draft.directoryURL)
    try manager.moveItem(at: draft.directoryURL, to: outgoingDirectory(id: draft.id))
    return outgoing
  }

  func outgoingShares() throws -> [KometOutgoingShare] {
    let directories = try manager.contentsOfDirectory(at: outgoingURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    var shares: [KometOutgoingShare] = []
    for directory in directories {
      guard let data = try? Data(contentsOf: directory.appendingPathComponent("outgoing.json")),
            let share = try? JSONDecoder().decode(KometOutgoingShare.self, from: data),
            share.id == directory.lastPathComponent, UUID(uuidString: share.id) != nil else { continue }
      shares.append(share)
    }
    return shares.sorted { $0.createdAt > $1.createdAt }
  }

  func outgoingRequest(_ share: KometOutgoingShare) throws -> [String: Any] {
    let directory = try outgoingDirectory(id: share.id)
    try validate(Manifest(id: share.id, createdAt: share.createdAt, files: share.files, text: share.text, subject: nil), at: directory)
    return [
      "id": share.id, "chat_id": share.chatID, "text": share.text ?? "",
      "state_path": directory.appendingPathComponent("send-state.json").path,
      "files": share.files.map { file -> [String: Any] in
        ["path": directory.appendingPathComponent(file.relativePath).path,
         "name": file.name, "mime": file.mime, "size": file.size]
      }
    ]
  }

  func updateOutgoing(_ share: KometOutgoingShare, status: String, message: String?) throws -> KometOutgoingShare {
    guard ["prepared", "sending", "failed", "unknown", "sent"].contains(status) else {
      throw KometShareError.invalidRequest
    }
    var updated = share
    updated.status = status
    updated.message = message
    try writeOutgoing(updated, at: outgoingDirectory(id: share.id))
    return updated
  }

  func removeOutgoing(id: String) throws {
    let directory = try outgoingDirectory(id: id)
    if manager.fileExists(atPath: directory.path) { try manager.removeItem(at: directory) }
  }

  private func outgoingDirectory(id: String) throws -> URL {
    guard UUID(uuidString: id) != nil, !id.contains("/"), !id.contains("\\") else { throw KometShareError.invalidRequest }
    return outgoingURL.appendingPathComponent(id, isDirectory: true)
  }

  private func writeOutgoing(_ share: KometOutgoingShare, at directory: URL) throws {
    var options: Data.WritingOptions = [.atomic]
    #if os(iOS)
    options.insert(.completeFileProtectionUntilFirstUserAuthentication)
    #endif
    try JSONEncoder().encode(share).write(to: directory.appendingPathComponent("outgoing.json"), options: options)
  }

  @discardableResult
  func importDocument(documentURL: URL) throws -> String {
    let draft = try beginRequest()
    do {
      let file = try copyFile(
        at: documentURL, suggestedName: nil, typeIdentifier: nil, into: draft
      )
      return try commit(draft, files: [file], text: nil, subject: nil)
    } catch {
      discard(draft)
      throw error
    }
  }

  func nextPayload() throws -> [String: Any]? {
    let directories = try manager.contentsOfDirectory(
      at: requestsURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
    )
    var candidates: [(manifest: Manifest, directory: URL, state: String)] = []
    for directory in directories {
      do {
        guard UUID(uuidString: directory.lastPathComponent) != nil else {
          throw KometShareError.invalidRequest
        }
        let state = try readState(at: directory)
        if state == "completed" { continue }
        guard state == "pending" || state == "claimed" else { throw KometShareError.invalidRequest }
        let manifest = try JSONDecoder().decode(
          Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        )
        guard manifest.id == directory.lastPathComponent else { throw KometShareError.invalidRequest }
        candidates.append((manifest, directory, state))
      } catch {
        try quarantine(directory)
        throw KometShareError.invalidRequest
      }
    }
    candidates.sort {
      if ($0.state == "claimed") != ($1.state == "claimed") { return $0.state == "claimed" }
      if $0.manifest.createdAt != $1.manifest.createdAt {
        return $0.manifest.createdAt < $1.manifest.createdAt
      }
      return $0.manifest.id < $1.manifest.id
    }
    guard let next = candidates.first else { return nil }
    do {
      try validate(next.manifest, at: next.directory)
    } catch {
      try quarantine(next.directory)
      throw KometShareError.invalidRequest
    }
    try writeState("claimed", at: next.directory)
    var payload: [String: Any] = [
      "id": next.manifest.id,
      "files": next.manifest.files.map { file -> [String: Any] in
        [
          "path": next.directory.appendingPathComponent(file.relativePath).path,
          "name": file.name,
          "mime": file.mime,
          "size": file.size
        ]
      }
    ]
    if let text = next.manifest.text { payload["text"] = text }
    if let subject = next.manifest.subject { payload["subject"] = subject }
    return payload
  }

  func acknowledge(id: String) throws {
    let directory = try requestURL(id: id)
    guard manager.fileExists(atPath: directory.path) else { return }
    let state = try readState(at: directory)
    guard state == "claimed" || state == "completed" else { throw KometShareError.invalidRequest }
    try writeState("completed", at: directory)
  }

  func removeCompleted(id: String) throws {
    let directory = try requestURL(id: id)
    guard manager.fileExists(atPath: directory.path) else { return }
    guard try readState(at: directory) == "completed" else { throw KometShareError.invalidRequest }
    try manager.removeItem(at: directory)
  }

  private func requestURL(id: String) throws -> URL {
    guard UUID(uuidString: id) != nil, !id.contains("/"), !id.contains("\\") else {
      throw KometShareError.invalidRequest
    }
    return requestsURL.appendingPathComponent(id, isDirectory: true)
  }

  private func quarantine(_ directory: URL) throws {
    try manager.createDirectory(at: quarantineURL, withIntermediateDirectories: true)
    try manager.moveItem(at: directory, to: quarantineURL.appendingPathComponent(UUID().uuidString))
  }

  private func destination(in draft: KometShareDraft, name: String) throws -> URL {
    let directory = draft.directoryURL.appendingPathComponent("attachments", isDirectory: true)
    let existing = try manager.contentsOfDirectory(atPath: directory.path)
    guard existing.count < Self.maximumAttachments else { throw KometShareError.tooManyAttachments }
    let suffix = (name as NSString).pathExtension
    let filename = UUID().uuidString.lowercased() + (suffix.isEmpty ? "" : ".\(suffix)")
    return directory.appendingPathComponent(filename)
  }

  private func fileMetadata(at url: URL, name: String, typeIdentifier: String) throws -> KometSharedFile {
    let attributes = try manager.attributesOfItem(atPath: url.path)
    guard let size = attributes[.size] as? NSNumber else { throw KometShareError.unreadableAttachment }
    let mime = UTTypeCopyPreferredTagWithClass(typeIdentifier as CFString, kUTTagClassMIMEType)?
      .takeRetainedValue() as String? ?? "application/octet-stream"
    return KometSharedFile(
      relativePath: "attachments/\(url.lastPathComponent)", name: name, mime: mime, size: size.int64Value
    )
  }

  private func validate(_ manifest: Manifest, at directory: URL) throws {
    guard !manifest.files.isEmpty || Self.nonempty(manifest.text) != nil,
          manifest.files.count <= Self.maximumAttachments else { throw KometShareError.invalidRequest }
    for file in manifest.files {
      let components = file.relativePath.split(separator: "/", omittingEmptySubsequences: false)
      guard components.count == 2, components[0] == "attachments",
            !components[1].isEmpty, components[1] != ".", components[1] != "..",
            !components[1].contains("\\") else { throw KometShareError.invalidRequest }
      let url = directory.appendingPathComponent(file.relativePath)
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
      guard values.isRegularFile == true, values.isSymbolicLink != true,
            values.fileSize.map(Int64.init) == file.size else { throw KometShareError.invalidRequest }
    }
  }

  private func writeState(_ state: String, at directory: URL) throws {
    try Data(state.utf8).write(to: directory.appendingPathComponent("state"), options: .atomic)
  }

  private func readState(at directory: URL) throws -> String {
    try String(contentsOf: directory.appendingPathComponent("state"), encoding: .utf8)
  }

  private static func resolvedType(_ advertised: String?, fileNames: [String?]) -> String {
    if let advertised = advertised {
      let mime = preferredTag(for: advertised, tagClass: kUTTagClassMIMEType)
      let suffix = preferredTag(for: advertised, tagClass: kUTTagClassFilenameExtension)
      if (mime != nil && mime != "application/octet-stream") || suffix != nil { return advertised }
    }
    let inferred = fileNames.compactMap { name -> String? in
      guard let name = name else { return nil }
      let suffix = (name as NSString).pathExtension
      guard !suffix.isEmpty else { return nil }
      return UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, suffix as CFString, nil)?
        .takeRetainedValue() as String?
    }
    return inferred.first {
      let mime = preferredTag(for: $0, tagClass: kUTTagClassMIMEType)
      return mime != nil && mime != "application/octet-stream"
    } ?? inferred.first ?? advertised ?? "public.data"
  }

  private static func preferredTag(for type: String, tagClass: CFString) -> String? {
    UTTypeCopyPreferredTagWithClass(type as CFString, tagClass)?.takeRetainedValue() as String?
  }

  private static func fileName(_ proposed: String, typeIdentifier: String) -> String {
    let last = (proposed.replacingOccurrences(of: "\\", with: "/") as NSString).lastPathComponent
    let cleaned = last.components(separatedBy: .controlCharacters).joined()
    var name = cleaned.isEmpty || cleaned == "." || cleaned == ".." ? "Вложение" : cleaned
    name = String(name.prefix(160))
    if (name as NSString).pathExtension.isEmpty,
       let suffix = UTTypeCopyPreferredTagWithClass(typeIdentifier as CFString, kUTTagClassFilenameExtension)?
         .takeRetainedValue() as String?, !suffix.isEmpty {
      name += ".\(suffix)"
    }
    return name
  }

  private static func nonempty(_ text: String?) -> String? {
    guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
  }
}
