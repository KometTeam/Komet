import Foundation
import ImageIO
import CoreGraphics
import CoreServices

@main
struct KometShareImagesTests {
  static func main() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? manager.removeItem(at: root) }
    let store = try KometShareStore(containerURL: root)
    let draft = try store.beginRequest()
    let fixtureURL = root.appendingPathComponent("large.png")
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: 5200, height: 1000, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      throw Failure(message: "Synthetic image context unavailable")
    }
    context.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 0.5))
    context.fill(CGRect(x: 0, y: 0, width: 5200, height: 1000))
    guard let image = context.makeImage() else { throw Failure(message: "Synthetic image unavailable") }
    try write(image, type: kUTTypePNG, to: fixtureURL)
    let imported = try store.copyFile(at: fixtureURL, suggestedName: "Synthetic photo", typeIdentifier: "public.image", into: draft)
    let generic = KometSharedFile(relativePath: imported.relativePath, name: "Synthetic photo", mime: "application/octet-stream", size: imported.size)
    let normalized = try KometShareSender.prepareImages([generic], in: draft)[0]
    try expect(normalized.mime == "image/jpeg" && normalized.name == "Synthetic photo.jpg", "Actual image bytes must determine generic provider content")
    let jpegURL = draft.directoryURL.appendingPathComponent(normalized.relativePath)
    guard let source = CGImageSourceCreateWithURL(jpegURL as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
      throw Failure(message: "Normalized image missing")
    }
    try expect(max(width, height) <= 2560, "Photo decode must be bounded to extension memory budget")
    try expect(CGImageSourceGetType(source).map { $0 as String } == "public.jpeg", "JPEG MIME must match actual encoded bytes")
    try expect(!manager.fileExists(atPath: draft.directoryURL.appendingPathComponent(imported.relativePath).path), "Normalization must release the original staging copy")
    let text = try store.saveData(Data("Synthetic text file".utf8), suggestedName: "document.txt", typeIdentifier: "public.plain-text", into: draft)
    let unchanged = try KometShareSender.prepareImages([text], in: draft)[0]
    try expect(unchanged.relativePath == text.relativePath && unchanged.mime == text.mime, "Documents must preserve their bytes and metadata")
    let heicURL = root.appendingPathComponent("synthetic.heic")
    if (CGImageDestinationCopyTypeIdentifiers() as! [String]).contains("public.heic") {
      try write(image, type: "public.heic" as CFString, to: heicURL)
      let heic = try store.copyFile(at: heicURL, suggestedName: "Synthetic.heic", typeIdentifier: "public.heic", into: draft)
      let converted = try KometShareSender.prepareImages([heic], in: draft)[0]
      try expect(converted.mime == "image/jpeg" && converted.name == "Synthetic.jpg", "HEIC must use actual JPEG bytes for photo upload")
    }
    let response = try KometShareSender.send(credentials: [:], request: [:]) { _, _, _ in }
    try expect(response.status == "unknown", "A missing transport result must not be presented as sent")
    print("KometShareImages: all tests passed")
  }

  static func write(_ image: CGImage, type: CFString, to url: URL) throws {
    guard let output = CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil) else {
      throw Failure(message: "Synthetic image destination unavailable")
    }
    CGImageDestinationAddImage(output, image, nil)
    guard CGImageDestinationFinalize(output) else { throw Failure(message: "Synthetic image encode failed") }
  }

  static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw Failure(message: message) }
  }

  struct Failure: Error { let message: String }
}
