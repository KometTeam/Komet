import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // #***! super здесь так же мёртв, как и у APNs-колбэков ниже: реализация
  // отсутствует во FlutterAppDelegate и форвардинг падает unrecognized selector
  override func applicationDidFinishLaunching(_ notification: Notification) {
    KometRemoteNotifications.shared.activate()
  }

  // #***! у FlutterAppDelegate на macOS нет рантайм-реализации APNs-колбэков:
  // вызов super уходит в _CF_forwarding_prep_0 → unrecognized selector → abort.
  // Override — единственный обработчик.
  override func application(
    _ application: NSApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    KometRemoteNotifications.shared.pushToken(deviceToken)
  }

  override func application(
    _ application: NSApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    KometRemoteNotifications.shared.pushTokenFailed(error)
  }

  override func application(
    _ application: NSApplication,
    didReceiveRemoteNotification userInfo: [String: Any]
  ) {
    KometRemoteNotifications.shared.remoteNotification(userInfo)
  }
}