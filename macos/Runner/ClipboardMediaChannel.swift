import Cocoa
import FlutterMacOS

enum ClipboardMediaChannel {
  private static let channelName = "ru.komet.app/clipboard"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "hasMedia":
        result(hasMedia())
      case "read":
        result(read())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func hasMedia() -> Bool {
    guard let types = NSPasteboard.general.types else { return false }
    return types.contains(.fileURL) || hasImage(types)
  }

  private static func hasImage(_ types: [NSPasteboard.PasteboardType]) -> Bool {
    guard types.contains(.png) || types.contains(.tiff) else { return false }
    return !types.contains(.string)
  }

  private static func read() -> [String: Any]? {
    let pasteboard = NSPasteboard.general
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] {
      let paths = urls.filter { $0.isFileURL }.map { $0.path }
      if !paths.isEmpty {
        return ["files": paths]
      }
    }
    guard let types = pasteboard.types, hasImage(types) else { return nil }
    if let png = pasteboard.data(forType: .png) {
      return image(from: png)
    }
    if let tiff = pasteboard.data(forType: .tiff),
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
      return image(from: png)
    }
    return nil
  }

  private static func image(from png: Data) -> [String: Any]? {
    guard !png.isEmpty else { return nil }
    return [
      "image": FlutterStandardTypedData(bytes: png),
      "imageExtension": ".png",
    ]
  }
}
