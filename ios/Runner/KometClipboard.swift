import Flutter
import UIKit

enum KometClipboard {
  private static let cacheDirectory = "clipboard_in"
  private static let retention: TimeInterval = 24 * 60 * 60
  private static let recodeQuality: CGFloat = 0.95
  private static let passthrough: [(type: String, ext: String)] = [
    ("public.png", "png"),
    ("public.jpeg", "jpg"),
    ("com.compuserve.gif", "gif"),
    ("org.webmproject.webp", "webp"),
  ]

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasMedia":
      result(UIPasteboard.general.hasImages)
    case "read":
      read(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func read(_ result: @escaping FlutterResult) {
    let pasteboard = UIPasteboard.general
    guard pasteboard.hasImages else {
      result(nil)
      return
    }

    let items = pasteboard.items
    DispatchQueue.global(qos: .userInitiated).async {
      let images = items.compactMap(image(in:))
      let paths = images.isEmpty ? [] : store(images)
      DispatchQueue.main.async {
        result(paths.isEmpty ? nil : ["files": paths])
      }
    }
  }

  private static func image(in item: [String: Any]) -> (data: Data, ext: String)? {
    for entry in passthrough {
      guard let data = item[entry.type] as? Data, !data.isEmpty else { continue }
      return (data, entry.ext)
    }
    for value in item.values {
      if let image = value as? UIImage, let jpeg = recoded(image) {
        return (jpeg, "jpg")
      }
      if let data = value as? Data,
         let image = UIImage(data: data),
         let jpeg = recoded(image) {
        return (jpeg, "jpg")
      }
    }
    return nil
  }

  private static func recoded(_ image: UIImage) -> Data? {
    guard let jpeg = image.jpegData(compressionQuality: recodeQuality), !jpeg.isEmpty else {
      return nil
    }
    return jpeg
  }

  private static func store(_ images: [(data: Data, ext: String)]) -> [String] {
    guard let root = cacheRoot() else { return [] }
    prune(root)

    let stamp = Int(Date().timeIntervalSince1970 * 1000)
    var paths: [String] = []
    for (index, payload) in images.enumerated() {
      let file = root.appendingPathComponent("paste_\(stamp)_\(index).\(payload.ext)")
      do {
        try payload.data.write(to: file, options: .atomic)
        paths.append(file.path)
      } catch {
        NSLog("KometClipboard: cannot store a pasted image: \(error)")
      }
    }
    return paths
  }

  private static func cacheRoot() -> URL? {
    let manager = FileManager.default
    guard let caches = manager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      return nil
    }
    let root = caches.appendingPathComponent(cacheDirectory, isDirectory: true)
    do {
      try manager.createDirectory(at: root, withIntermediateDirectories: true)
    } catch {
      NSLog("KometClipboard: cannot create the paste cache: \(error)")
      return nil
    }
    return root
  }

  private static func prune(_ root: URL) {
    let manager = FileManager.default
    let cutoff = Date().addingTimeInterval(-retention)
    guard let entries = try? manager.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: [.contentModificationDateKey]
    ) else { return }

    for entry in entries {
      let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey])
      if let modified = values?.contentModificationDate, modified > cutoff { continue }
      try? manager.removeItem(at: entry)
    }
  }
}
