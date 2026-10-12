import Foundation

@main
struct KometShareStoreTests {
  static func main() throws {
    let manager = FileManager.default
    let container = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? manager.removeItem(at: container) }
    let store = try KometShareStore(containerURL: container)

    let abandoned = try store.beginRequest()
    _ = try store.saveData(Data("uncommitted".utf8), suggestedName: "draft.txt", typeIdentifier: "public.plain-text", into: abandoned)
    try expect(store.nextPayload() == nil, "Uncommitted requests must not be visible")
    store.discard(abandoned)

    let first = try store.beginRequest()
    let attachment = try store.saveData(Data(), suggestedName: "empty.txt", typeIdentifier: "public.plain-text", into: first)
    let firstID = try store.commit(first, files: [attachment], text: " Synthetic caption ", subject: nil)
    let second = try store.beginRequest()
    let secondID = try store.commit(second, files: [], text: "https://example.test/shared", subject: nil)
    let payload = try require(store.nextPayload(), "First payload is missing")
    try expect(payload["id"] as? String == firstID, "Requests must preserve order")
    try expect(payload["text"] as? String == "Synthetic caption", "Text must be normalized")
    let files = try require(payload["files"] as? [[String: Any]], "File metadata is missing")
    let path = try require(files.first?["path"] as? String, "Attachment path is missing")
    try expect(manager.fileExists(atPath: path), "Empty documents must be accepted")

    let restarted = try KometShareStore(containerURL: container)
    try expect(restarted.nextPayload()?["id"] as? String == firstID, "Claim must survive process restart")
    try restarted.acknowledge(id: firstID)
    try expect(manager.fileExists(atPath: path), "Acknowledgment must not remove attachment bytes")
    try expect(restarted.nextPayload()?["id"] as? String == secondID, "Acknowledgment must advance the queue")
    try restarted.removeCompleted(id: firstID)
    try expect(!manager.fileExists(atPath: path), "Explicit release must remove exact completed request")
    try restarted.acknowledge(id: firstID)
    try restarted.removeCompleted(id: firstID)
    try expect(restarted.nextPayload()?["id"] as? String == secondID, "Idempotent release must preserve the next request")

    try expectThrows { try restarted.removeCompleted(id: secondID) }
    try expectThrows { try restarted.acknowledge(id: "../invalid") }
    try restarted.acknowledge(id: secondID)
    try restarted.removeCompleted(id: secondID)

    let broken = try restarted.beginRequest()
    let brokenFile = try restarted.saveData(Data("fixture".utf8), suggestedName: "sample.txt", typeIdentifier: "public.plain-text", into: broken)
    let brokenID = try restarted.commit(broken, files: [brokenFile], text: nil, subject: nil)
    let missing = container.appendingPathComponent("KometShare/requests/\(brokenID)/\(brokenFile.relativePath)")
    try manager.removeItem(at: missing)
    let later = try restarted.beginRequest()
    let laterID = try restarted.commit(later, files: [], text: "Later synthetic share", subject: nil)
    try expectThrows { _ = try restarted.nextPayload() }
    try expect(restarted.nextPayload()?["id"] as? String == laterID, "Corrupt requests must not permanently block the queue")

    let oversized = try restarted.beginRequest()
    for index in 0..<KometShareStore.maximumAttachments {
      _ = try restarted.saveData(Data(), suggestedName: "fixture-\(index).txt", typeIdentifier: "public.plain-text", into: oversized)
    }
    try expectThrows {
      _ = try restarted.saveData(Data(), suggestedName: "overflow.txt", typeIdentifier: "public.plain-text", into: oversized)
    }
    restarted.discard(oversized)

    let external = container.appendingPathComponent("external.txt")
    try Data("Imported synthetic document".utf8).write(to: external)
    _ = try restarted.importDocument(documentURL: external)
    try expect(manager.fileExists(atPath: external.path), "Document import must preserve the original")

    let typed = try restarted.beginRequest()
    let imageURL = container.appendingPathComponent("synthetic.png")
    try Data("synthetic image bytes".utf8).write(to: imageURL)
    let image = try restarted.copyFile(
      at: imageURL, suggestedName: "Shared image", typeIdentifier: "public.image", into: typed
    )
    try expect(image.mime == "image/png", "Abstract image type must use the source file type")
    try expect(image.name == "Shared image.png", "Inferred image type must add its proper extension")
    let pdfURL = container.appendingPathComponent("synthetic.pdf")
    try Data("synthetic PDF bytes".utf8).write(to: pdfURL)
    let pdf = try restarted.copyFile(
      at: pdfURL, suggestedName: "Shared document", typeIdentifier: "public.data", into: typed
    )
    try expect(pdf.mime == "application/pdf", "Generic data type must use the document file type")
    try expect(pdf.name == "Shared document.pdf", "Inferred document type must add its proper extension")
    let advertised = try restarted.copyFile(
      at: imageURL, suggestedName: "Specific image", typeIdentifier: "public.jpeg", into: typed
    )
    try expect(advertised.mime == "image/jpeg", "Specific advertised types must retain priority")
    let named = try restarted.saveData(
      Data("synthetic named image".utf8), suggestedName: "Shared.png", typeIdentifier: "public.image", into: typed
    )
    try expect(named.mime == "image/png", "Generic data representation must infer its type from the suggested name")
    restarted.discard(typed)

    let direct = try restarted.beginRequest()
    let directFile = try restarted.saveData(Data("synthetic direct share".utf8), suggestedName: "direct.txt", typeIdentifier: "public.plain-text", into: direct)
    let outgoing = try restarted.prepareOutgoing(direct, files: [directFile], text: "Caption", accountID: "12", chatID: "34", chatTitle: "Synthetic recipient")
    let outbox = try restarted.outgoingShares()
    try expect(outbox.count == 1 && outbox[0].id == direct.id, "Direct sends must persist in a separate outbox")
    let outgoingPayload = try restarted.outgoingRequest(outgoing)
    let outgoingFiles = try require(outgoingPayload["files"] as? [[String: Any]], "Outgoing files are missing")
    let outgoingPath = try require(outgoingFiles.first?["path"] as? String, "Outgoing file path is missing")
    try expect(manager.fileExists(atPath: outgoingPath), "Outgoing bytes must survive staging commit")
    _ = try restarted.updateOutgoing(outgoing, status: "unknown", message: "Synthetic missing acknowledgement")
    let afterSendRestart = try KometShareStore(containerURL: container)
    try expect(afterSendRestart.outgoingShares().first?.status == "unknown", "Unknown network outcomes must survive restart")
    while let queued = try afterSendRestart.nextPayload(), let id = queued["id"] as? String {
      try expect(id != outgoing.id, "Native direct shares must never become interactive queued shares")
      try afterSendRestart.acknowledge(id: id)
      try afterSendRestart.removeCompleted(id: id)
    }
    try expect(manager.fileExists(atPath: outgoingPath), "Host queue cleanup must not remove native outbox files")
    try expectThrows { try afterSendRestart.removeOutgoing(id: "../invalid") }
    try afterSendRestart.removeOutgoing(id: outgoing.id)
    try afterSendRestart.removeOutgoing(id: outgoing.id)
    try expect(afterSendRestart.outgoingShares().isEmpty, "Explicit outbox deletion must be idempotent")
    print("KometShareStore: all tests passed")
  }

  static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw Failure(message: message) }
  }

  static func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value = value else { throw Failure(message: message) }
    return value
  }

  static func expectThrows(_ operation: () throws -> Void) throws {
    do {
      try operation()
    } catch {
      return
    }
    throw Failure(message: "Expected operation to reject invalid input")
  }

  struct Failure: Error {
    let message: String
  }
}
