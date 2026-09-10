import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.setFrameAutosaveName("MainWindow")
    RegisterGeneratedPlugins(registry: flutterViewController)
    ClipboardMediaChannel.register(
      messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
