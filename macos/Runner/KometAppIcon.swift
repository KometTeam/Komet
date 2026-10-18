import AppKit
import FlutterMacOS

final class KometAppIcon {
  static let defaultsKey = "komet_mac_app_icon"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "ru.komet.app/app_icon", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setAppIcon":
        let name = (call.arguments as? [String: Any])?["name"] as? String
        if applyIcon(name) {
          result(nil)
        } else {
          result(FlutterError(
            code: "_ICON_NOT_FOUND",
            message: "Icon resource not found",
            details: nil
          ))
        }
      case "getAppIcon":
        result(UserDefaults.standard.string(forKey: defaultsKey))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // #***! Dock-иконка в macos не переживает перезапуск — восстановление при
  // каждом старте. nil возвращает иконку бандла из Assets.car: она appearance-
  // осведомлённая (light/dark/clear/tinted), в отличие от ручной картинки.
  static func restoreAtLaunch() {
    guard let name = UserDefaults.standard.string(forKey: defaultsKey),
          !name.isEmpty
    else {
      return
    }
    applyIcon(name)
  }

  @discardableResult
  static func applyIcon(_ name: String?) -> Bool {
    if name == nil || name!.isEmpty {
      NSLog("KometAppIcon: сброс к иконке бандла")
      NSApplication.shared.applicationIconImage = nil
      UserDefaults.standard.removeObject(forKey: defaultsKey)
      return true
    }
    // #***! альтернативы лежат в Assets.car стеками со всеми вариантами —
    // NSImage(named:) отдаёт appearance-aware картинку
    guard let image = NSImage(named: name!) else {
      NSLog("KometAppIcon: картинка %@ не найдена", name!)
      return false
    }
    NSLog("KometAppIcon: применена %@", name!)
    NSApplication.shared.applicationIconImage = image
    UserDefaults.standard.set(name, forKey: defaultsKey)
    return true
  }
}