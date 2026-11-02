import Foundation
import ImageIO
#if canImport(MobileCoreServices)
import MobileCoreServices
#else
import CoreServices
#endif
import CoreGraphics

struct KometShareSendResult {
  let status: String
  let message: String
  var refreshedToken: String? = nil
}

private final class KometShareProgressContext {
  let update: (String, Double?, String) -> Void

  init(update: @escaping (String, Double?, String) -> Void) {
    self.update = update
  }
}

private let kometShareProgressCallback: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = { json, context in
  guard let json = json, let context = context,
        let data = String(cString: json).data(using: .utf8),
        let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
  let receiver = Unmanaged<KometShareProgressContext>.fromOpaque(context).takeUnretainedValue()
  let message = payload["message"] as? String ?? "Отправляем…"
  let progress = (payload["progress"] as? Double).map { min(1, max(0, $0)) }
  receiver.update(message, progress, payload["phase"] as? String ?? "connecting")
}

final class KometShareSender {
  static func send(
    credentials: [String: Any], request: [String: Any],
    progress: @escaping (String, Double?, String) -> Void
  ) throws -> KometShareSendResult {
    var input = credentials
    input["request"] = request
    let data = try JSONSerialization.data(withJSONObject: input)
    guard let json = String(data: data, encoding: .utf8) else { throw KometShareError.invalidRequest }
    let context = KometShareProgressContext(update: progress)
    let response = withExtendedLifetime(context) {
      json.withCString { value in
        komet_share_send(value, kometShareProgressCallback, Unmanaged.passUnretained(context).toOpaque())
      }
    }
    guard let response = response else {
      return KometShareSendResult(status: "unknown", message: "Не удалось подтвердить отправку. Проверьте чат в Komet перед повторной отправкой.")
    }
    defer { komet_share_free(response) }
    guard let data = String(cString: response).data(using: .utf8),
          let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let status = payload["status"] as? String, ["sent", "failed", "unknown"].contains(status) else {
      return KometShareSendResult(status: "unknown", message: "Не удалось подтвердить отправку. Проверьте чат в Komet перед повторной отправкой.")
    }
    return KometShareSendResult(
      status: status, message: payload["message"] as? String ?? "Не удалось подтвердить отправку.",
      refreshedToken: payload["refreshed_token"] as? String
    )
  }

  static func prepareImages(_ files: [KometSharedFile], in draft: KometShareDraft) throws -> [KometSharedFile] {
    try files.map { file in
      try autoreleasepool {
        let url = draft.directoryURL.appendingPathComponent(file.relativePath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
          if file.mime.hasPrefix("image/") { throw KometShareError.unreadableAttachment }
          return file
        }
        guard let type = CGImageSourceGetType(source), UTTypeConformsTo(type, kUTTypeImage) else { return file }
        if CGImageSourceGetCount(source) > 1 {
          return KometSharedFile(relativePath: file.relativePath, name: file.name, mime: "application/octet-stream", size: file.size)
        }
        let options: [CFString: Any] = [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 2560,
          kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: thumbnail.width, height: thumbnail.height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
          throw KometShareError.unreadableAttachment
        }
        let bounds = CGRect(x: 0, y: 0, width: thumbnail.width, height: thumbnail.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.draw(thumbnail, in: bounds)
        guard let image = context.makeImage() else { throw KometShareError.unreadableAttachment }
        let destinationURL = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString.lowercased() + ".jpg")
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypeJPEG, 1, nil) else {
          throw KometShareError.unreadableAttachment
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
          try? FileManager.default.removeItem(at: destinationURL)
          throw KometShareError.unreadableAttachment
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        guard let size = attributes[.size] as? NSNumber else { throw KometShareError.unreadableAttachment }
        try FileManager.default.removeItem(at: url)
        return KometSharedFile(
          relativePath: "attachments/\(destinationURL.lastPathComponent)",
          name: (file.name as NSString).deletingPathExtension + ".jpg",
          mime: "image/jpeg", size: size.int64Value
        )
      }
    }
  }
}
