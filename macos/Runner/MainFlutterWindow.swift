import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var lastMouseDownEvent: NSEvent?

  override func awakeFromNib() {
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    styleMask.insert(.fullSizeContentView)

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.setFrameAutosaveName("MainWindow")
    RegisterGeneratedPlugins(registry: flutterViewController)
    ClipboardMediaChannel.register(
      messenger: flutterViewController.engine.binaryMessenger)
    ShareInboxBridge.register(
      messenger: flutterViewController.engine.binaryMessenger)
    KometRemoteNotifications.register(
      messenger: flutterViewController.engine.binaryMessenger)
    KometAppIcon.register(
      messenger: flutterViewController.engine.binaryMessenger)
    setupChromelessTitleBar(
      messenger: flutterViewController.engine.binaryMessenger)

    delegate = self
    Self.startActivationObserver()
    KometAppIcon.restoreAtLaunch()

    super.awakeFromNib()
  }

  private func setupChromelessTitleBar(messenger: FlutterBinaryMessenger) {
    NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) {
      [weak self] event in
      if event.window === self {
        self?.lastMouseDownEvent = event
      }
      return event
    }

    let channel = FlutterMethodChannel(
      name: "ru.komet.app/window", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "startDrag":
        result(nil)
        if let event = self.lastMouseDownEvent, event.window === self {
          self.performDrag(with: event)
        }
      case "toggleZoom":
        self.performZoom(self)
        result(nil)
      case "titleInset":
        result(self.titleInset)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private var titleInset: Double {
    if #available(macOS 11.0, *) {
      let inset = contentView?.safeAreaInsets.top ?? 0
      if inset > 0 {
        return inset
      }
    }
    return 28
  }
}

extension MainFlutterWindow: NSWindowDelegate {
  // #***! закрытие окна прячет UI, процесс продолжает работать в фоне
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    return false
  }
}

extension MainFlutterWindow {
  static func startActivationObserver() {
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { notification in
      guard let app = notification.object as? NSApplication else { return }
      for window in app.windows where window is MainFlutterWindow && !window.isVisible {
        window.makeKeyAndOrderFront(nil)
        break
      }
    }
  }
}