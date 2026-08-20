import Flutter
import UIKit

final class KometStreamHandler: NSObject, FlutterStreamHandler {
  private let onSink: (FlutterEventSink?) -> Void

  init(onSink: @escaping (FlutterEventSink?) -> Void) {
    self.onSink = onSink
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    onSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onSink(nil)
    return nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var channels: [FlutterMethodChannel] = []
  private var eventChannels: [FlutterEventChannel] = []
  private var streamHandlers: [KometStreamHandler] = []
  private var videoNote: KometVideoNote?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    KometNotifications.shared.start()

    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger
      registerAppIcon(messenger)
      registerVideo(messenger)
      registerVideoNote(messenger)
      registerNotifications(messenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func method(_ name: String, _ messenger: FlutterBinaryMessenger,
                      _ handler: @escaping FlutterMethodCallHandler) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler(handler)
    channels.append(channel)
  }

  private func events(_ name: String, _ messenger: FlutterBinaryMessenger,
                      _ onSink: @escaping (FlutterEventSink?) -> Void) {
    let handler = KometStreamHandler(onSink: onSink)
    let channel = FlutterEventChannel(name: name, binaryMessenger: messenger)
    channel.setStreamHandler(handler)
    streamHandlers.append(handler)
    eventChannels.append(channel)
  }

  private func registerAppIcon(_ messenger: FlutterBinaryMessenger) {
    method("ru.komet.app/app_icon", messenger) { call, result in
      guard call.method == "setAppIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let name = (call.arguments as? [String: Any])?["name"] as? String
      let iconName: String? = (name == "DefaultIcon") ? nil : name
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(code: "UNSUPPORTED",
                            message: "Alternate icons are not supported",
                            details: nil))
        return
      }
      UIApplication.shared.setAlternateIconName(iconName) { error in
        if let error = error {
          result(FlutterError(code: "APPLY_FAILED",
                              message: error.localizedDescription,
                              details: nil))
        } else {
          result(nil)
        }
      }
    }
  }

  private func registerVideo(_ messenger: FlutterBinaryMessenger) {
    method("ru.komet.app/video", messenger) { call, result in
      KometVideo.shared.handle(call, result: result)
    }
  }

  private func registerVideoNote(_ messenger: FlutterBinaryMessenger) {
    guard let textures = registrar(forPlugin: "KometVideoNote")?.textures() else { return }

    method("ru.komet.app/video_note", messenger) { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "permission":
        KometVideoNote.requestPermission(result)
      case "init":
        let args = call.arguments as? [String: Any] ?? [:]
        self.videoNote?.dispose()
        let recorder = KometVideoNote(registry: textures)
        self.videoNote = recorder
        recorder.initialize(
          front: (args["front"] as? NSNumber)?.boolValue ?? true,
          edge: (args["size"] as? NSNumber)?.intValue ?? 480,
          fps: (args["fps"] as? NSNumber)?.intValue ?? 30,
          result: result)
      case "start":
        self.withRecorder(result) { $0.start(result: result) }
      case "switch":
        self.withRecorder(result) { $0.switchCamera(result: result) }
      case "torch":
        let on = ((call.arguments as? [String: Any])?["on"] as? NSNumber)?.boolValue ?? false
        self.withRecorder(result) { $0.setTorch(on: on, result: result) }
      case "stop":
        self.withRecorder(result) { $0.stop(result: result) }
      case "dispose":
        self.videoNote?.dispose()
        self.videoNote = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func withRecorder(_ result: @escaping FlutterResult,
                            _ body: (KometVideoNote) -> Void) {
    guard let recorder = videoNote else {
      result(FlutterError(code: "NOT_READY", message: "recorder not initialized", details: nil))
      return
    }
    body(recorder)
  }

  private func registerNotifications(_ messenger: FlutterBinaryMessenger) {
    method("ru.komet.app/notifications", messenger) { call, result in
      KometNotifications.shared.handle(call, result: result)
    }
    events("ru.komet.app/notification_events", messenger) { sink in
      KometNotifications.shared.attach(sink)
    }
  }
}
