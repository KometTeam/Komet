import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      let channel = FlutterMethodChannel(
        name: "ru.komet.app/app_icon",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { (call, result) in
        guard call.method == "setAppIcon" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any]
        let name = args?["name"] as? String
        let iconName: String? = (name == "DefaultIcon") ? nil : name
        if !UIApplication.shared.supportsAlternateIcons {
          result(FlutterError(
            code: "UNSUPPORTED",
            message: "Alternate icons are not supported",
            details: nil
          ))
          return
        }
        UIApplication.shared.setAlternateIconName(iconName) { error in
          if let error = error {
            result(FlutterError(
              code: "APPLY_FAILED",
              message: error.localizedDescription,
              details: nil
            ))
          } else {
            result(nil)
          }
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
