import Flutter
import UIKit
import PushKit

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
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var channels: [FlutterMethodChannel] = []
  private var eventChannels: [FlutterEventChannel] = []
  private var streamHandlers: [KometStreamHandler] = []
  private var videoNote: KometVideoNote?
  private let shareBridge = KometShareBridge()
  private var flutterMessenger: FlutterBinaryMessenger?
  private var voipRegistry: PKPushRegistry?
  private var pendingVoipToken: String?
  private var channelsRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    KometNotifications.shared.start()

    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger
      registerAllChannels(
        messenger,
        textures: nil,
        includeClipboard: true
      )
    }

    setupVoipRegistry()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.isFileURL else {
      return super.application(app, open: url, options: options)
    }
    shareBridge.importDocument(url) { [weak self] error in
      guard var controller = self?.window?.rootViewController else { return }
      while let presented = controller.presentedViewController { controller = presented }
      let alert = UIAlertController(title: "Не удалось открыть файл",
                                    message: error.localizedDescription,
                                    preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "ОК", style: .default))
      controller.present(alert, animated: true)
    }
    return true
  }

  private func setupVoipRegistry() {
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry
    print("KometCallKit: PushKit registered, desiredTypes=[.voIP]")
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    registerAllChannels(
      messenger,
      textures: engineBridge.applicationRegistrar.textures(),
      includeClipboard: false
    )
    flutterMessenger = messenger
  }

  private func registerAllChannels(
    _ messenger: FlutterBinaryMessenger,
    textures: FlutterTextureRegistry? = nil,
    includeClipboard: Bool = true
  ) {
    guard !channelsRegistered else { return }
    channelsRegistered = true
    registerAppIcon(messenger)
    registerVideo(messenger)
    registerVideoNote(messenger, textures: textures)
    registerNotifications(messenger)
    registerScreen(messenger)
    registerShare(messenger)
    registerCalls(messenger)
    if includeClipboard {
      registerClipboard(messenger)
    }
  }

@objc override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    KometNotifications.shared.didReceivePushToken(deviceToken)
  }

  @objc override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    KometNotifications.shared.didFailToRegister(error)
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
      switch call.method {
      case "getAppIcon":
        result(UIApplication.shared.alternateIconName)
      case "setAppIcon":
        let requested = (call.arguments as? [String: Any])?["name"] as? String
        let iconName: String? = (requested?.isEmpty ?? true) ? nil : requested
        guard UIApplication.shared.supportsAlternateIcons else {
          result(FlutterError(code: "UNSUPPORTED",
                              message: "Alternate icons are not supported",
                              details: nil))
          return
        }
        guard UIApplication.shared.alternateIconName != iconName else {
          result(nil)
          return
        }
        UIApplication.shared.setAlternateIconName(iconName) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "APPLY_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
            } else {
              result(nil)
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerVideo(_ messenger: FlutterBinaryMessenger) {
    method("ru.komet.app/video", messenger) { call, result in
      KometVideo.shared.handle(call, result: result)
    }
  }

  private func registerVideoNote(
    _ messenger: FlutterBinaryMessenger,
    textures: FlutterTextureRegistry? = nil
  ) {
    guard
      let textures = textures ?? registrar(forPlugin: "KometVideoNote")?.textures()
    else { return }

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
          cameraId: args["cameraId"] as? String,
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

  private func registerScreen(_ messenger: FlutterBinaryMessenger) {
    method("ru.komet.app/screen", messenger) { call, result in
      switch call.method {
      case "setKeepAwake":
        let enabled = ((call.arguments as? [String: Any])?["enabled"] as? NSNumber)?.boolValue ?? false
        DispatchQueue.main.async {
          UIApplication.shared.isIdleTimerDisabled = enabled
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerShare(_ messenger: FlutterBinaryMessenger) {
    method("ru.komet.app/share", messenger) { [weak self] call, result in
      self?.shareBridge.handle(call, result: result)
    }
    events("ru.komet.app/share_events", messenger) { [weak self] sink in
      self?.shareBridge.attach(sink)
    }
  }

  private func registerClipboard(_ messenger: FlutterBinaryMessenger) {
    method("ru.komet.app/clipboard", messenger) { call, result in
      KometClipboard.handle(call, result: result)
    }
  }

  private func registerCalls(_ messenger: FlutterBinaryMessenger) {
    method("ru.komet.app/calls", messenger) { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "reportIncomingCall":
        let conversationId = args["conversationId"] as? String ?? ""
        let callerName = args["callerName"] as? String ?? "Неизвестный номер"
        let isVideo = args["isVideo"] as? Bool ?? false
        let vcp = args["vcp"] as? String
        let callerId = (args["callerId"] as? NSNumber)?.intValue
        KometCallKit.shared.reportIncomingCall(
          conversationId: conversationId,
          callerName: callerName,
          isVideo: isVideo,
          vcp: vcp,
          callerId: callerId
        )
        result(nil)
      case "reportOutgoingCall":
        let conversationId = args["conversationId"] as? String ?? ""
        let callerName = args["callerName"] as? String ?? "Неизвестный номер"
        let callerId = (args["callerId"] as? NSNumber)?.intValue
        let isVideo = args["isVideo"] as? Bool ?? false
        KometCallKit.shared.reportOutgoingCall(
          conversationId: conversationId,
          callerName: callerName,
          callerId: callerId,
          isVideo: isVideo
        )
        result(nil)
      case "endCall":
        let conversationId = args["conversationId"] as? String ?? ""
        KometCallKit.shared.endCall(conversationId: conversationId)
        KometPiP.shared.stop()
        result(nil)
      case "notifyAccepted":
        result(nil)
      case "notifyEnded":
        KometCallKit.shared.endAllCalls()
        KometPiP.shared.stop()
        result(nil)
      case "cancelIncoming":
        KometCallKit.shared.cancelIncoming()
        result(nil)
      case "ensureOngoing":
        result(nil)
      case "dropOngoing":
        KometCallKit.shared.endAllCalls()
        KometPiP.shared.stop()
        result(nil)
      case "consumeInitialCall":
        result(nil)
      case "setPiPTrack":
        if let trackId = args["trackId"] as? String {
          KometPiP.shared.attachTrack(trackId)
        }
        result(nil)
      case "clearPiPTracks":
        KometPiP.shared.stop()
        result(nil)
      case "setScreenShare":
        result(nil)
      case "syncCallerNames":
        let namesRaw = args["names"] as? [String: Any] ?? [:]
        let phonesRaw = args["phones"] as? [String: Any] ?? [:]
        var names = [Int: String]()
        for (k, v) in namesRaw {
          if let id = Int(k), let s = v as? String { names[id] = s }
        }
        var phones = [Int: Int]()
        for (k, v) in phonesRaw {
          if let id = Int(k), let n = (v as? NSNumber)?.intValue { phones[id] = n }
        }
        KometCallKit.shared.syncCallerNames(names, phones: phones)
        result(nil)
      case "callViaPhone":
        let phone = (args["phone"] as? NSNumber)?.intValue ?? 0
        if phone > 0,
           let url = URL(string: "tel:+\(phone)"),
           UIApplication.shared.canOpenURL(url) {
          DispatchQueue.main.async {
            UIApplication.shared.open(url) { ok in result(ok) }
          }
        } else {
          result(false)
        }
      case "canUseFullScreenIntent":
        result(true)
      case "openFullScreenIntentSettings":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    events("ru.komet.app/calls_events", messenger) { sink in
      KometCallKit.shared.attach(sink)
    }
  }

  private func registerNotifications(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "ru.komet.app/notifications", binaryMessenger: messenger)
    KometNotifications.shared.setChannel(channel)
    channel.setMethodCallHandler { call, result in
      if call.method == "consumeVoipToken" {
        result(self.pendingVoipToken)
        self.pendingVoipToken = nil
        return
      }
      if call.method == "requestVoipRegistration" {
        self.voipRegistry?.desiredPushTypes = [.voIP]
        result(nil)
        return
      }
      if call.method == "reregisterApns" {
        KometNotifications.shared.reregister()
        result(nil)
        return
      }
      KometNotifications.shared.handle(call, result: result)
    }
    channels.append(channel)
    events("ru.komet.app/notification_events", messenger) { sink in
      KometNotifications.shared.attach(sink)
    }
  }
}

extension AppDelegate: PKPushRegistryDelegate {
  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    let dict = payload.dictionaryPayload
    let conversationId = dict["conversationId"] as? String ?? ""
    if dict["ended"] as? Bool == true {
      // #***! звонящий сбросил: гасим висящий CallKit-экран
      KometCallKit.shared.endCall(conversationId: conversationId)
      completion()
      return
    }
    let callerName = dict["callerName"] as? String ?? "Неизвестный номер"
    let isVideo = dict["isVideo"] as? Bool ?? false
    let vcp = dict["vcp"] as? String
    let callerId = (dict["callerId"] as? NSNumber)?.intValue
    KometCallKit.shared.reportIncomingCall(
      conversationId: conversationId,
      callerName: callerName,
      isVideo: isVideo,
      vcp: vcp,
      callerId: callerId
    )
    completion()
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate credentials: PKPushCredentials,
    for type: PKPushType
  ) {
    let token = credentials.token.map { String(format: "%02x", $0) }.joined()
    print("KometCallKit: VoIP token received: \(token.prefix(16))...")
    pendingVoipToken = token
    guard let messenger = flutterMessenger else {
      print("KometCallKit: messenger nil, stored pendingVoipToken")
      return
    }
    let channel = FlutterMethodChannel(name: "ru.komet.app/notifications", binaryMessenger: messenger)
    channel.invokeMethod("onVoipToken", arguments: token)
    print("KometCallKit: VoIP token sent to Flutter")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didInvalidatePushTokenFor type: PKPushType
  ) {
    print("KometCallKit: VoIP token invalidated")
  }
}
