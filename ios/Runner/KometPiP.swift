import AVFoundation
import AVKit
import CoreMedia
import Flutter
import Foundation
import UIKit
import WebRTC
import flutter_webrtc

// Плавающее окно собеседника на время CallKit-звонка (паттерн Adopting PiP
// for video calls): кадры удалённой видеотреки flutter_webrtc гоним в
// AVSampleBufferDisplayLayer (слой SampleBufferVideoCallView внутри
// AVPictureInPictureVideoCallViewController) и поднимаем
// AVPictureInPictureController. Кадры ставятся с DisplayImmediately — без
// таймбейза слой показывает их сразу. Контроллер PiP создаётся лениво — по
// первому кадру, поэтому у аудио звонков окна нет. Трек передаётся с Dart
// каналом ru.komet.app/calls (setPiPTrack), жизненный цикл — через
// NotificationCenter, работает и со сценовым манифестом.
final class KometPiP: NSObject,
    AVPictureInPictureControllerDelegate,
    RTCVideoRenderer {
  static let shared = KometPiP()

  private var pipController: AVPictureInPictureController?
  private var pipVideoController: KometPiPContentViewController?
  private var sampleView: SampleBufferVideoCallView?
  private var sinks: [String: RTCVideoTrack] = [:]
  private var controllerRequested = false
  private var shouldRender = false

  private override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  var isStarted: Bool { pipController != nil }

  // Привязка удалённой видеотреки звонка; вызывается из Dart при бинде трека.
  // Sink'и ставим на ВСЕ кандидаты (SFU публикует слоты, часть пустая), а PiP
  // показывает ту дорожку, с которой реально идут кадры.
  func attachTrack(_ id: String) {
    guard sinks[id] == nil else { return }
    guard let track = resolveTrack(id) else {
      print("KometPiP: track \(id.prefix(12)) not found yet")
      return
    }
    sinks[id] = track
    track.add(self)
  }

  func showFloating() {
    guard let controller = pipController,
          controller.isPictureInPicturePossible,
          !controller.isPictureInPictureActive
    else {
      return
    }
    controller.startPictureInPicture()
  }

  func stop() {
    for track in sinks.values {
      track.remove(self)
    }
    sinks.removeAll()
    if let controller = pipController, controller.isPictureInPictureActive {
      controller.stopPictureInPicture()
    }
    pipController = nil
    pipVideoController = nil
    controllerRequested = false
    shouldRender = false
    sampleView?.sampleBufferDisplayLayer.flush()
    sampleView?.removeFromSuperview()
    sampleView = nil
  }

  @objc private func appDidBecomeActive() {
    if let controller = pipController, controller.isPictureInPictureActive {
      controller.stopPictureInPicture()
    }
  }

  private func resolveTrack(_ id: String) -> RTCVideoTrack? {
    guard let plugin = FlutterWebRTCPlugin.sharedSingleton() else { return nil }
    return plugin.track(forId: id, peerConnectionId: nil) as? RTCVideoTrack
  }

  private func setUpController() {
    guard AVPictureInPictureController.isPictureInPictureSupported(),
          let window = keyWindow(),
          let root = window.rootViewController?.view
    else {
      print("KometPiP: controller unavailable (supported/window)")
      return
    }

    let sample = SampleBufferVideoCallView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    sample.backgroundColor = .black
    sampleView = sample

    let content = KometPiPContentViewController()
    content.preferredContentSize = CGSize(width: 1080, height: 1920)
    content.view.backgroundColor = .black
    content.view.addSubview(sample)
    content.onLayout = { [weak sample] in
      guard let sample = sample else { return }
      sample.frame = sample.superview?.bounds ?? CGRect.zero
    }
    pipVideoController = content

    // Source view — видимая inline-презентация звонка: корневая вьюха,
    // на ней и рисуется видео в приложении. Старт PiP — только
    // автоматический (canStartPictureInPictureAutomaticallyFromInline),
    // ручной на willResignActive проигрывает гонку с переходом в фон
    let contentSource = AVPictureInPictureController.ContentSource(
      activeVideoCallSourceView: root,
      contentViewController: content
    )
    let controller = AVPictureInPictureController(contentSource: contentSource)
    controller.canStartPictureInPictureAutomaticallyFromInline = true
    controller.delegate = self
    pipController = controller
    print("KometPiP: controller ready, possible=\(controller.isPictureInPicturePossible)")
  }

  private func keyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  // RTCVideoRenderer
  @objc func setSize(_ size: CGSize) {}

  @objc func renderFrame(_ frame: RTCVideoFrame?) {
    guard let frame = frame else { return }
    guard let rtcBuffer = frame.buffer as? RTCCVPixelBuffer else { return }
    let pixelBuffer = rtcBuffer.pixelBuffer

    if pipController == nil, !controllerRequested, !sinks.isEmpty {
      controllerRequested = true
      DispatchQueue.main.async { [weak self] in
        guard let self = self, !self.sinks.isEmpty else { return }
        self.setUpController()
        print("KometPiP: controller created on first frame")
      }
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard let sample = self.sampleView, self.shouldRender else { return }
      let layer = sample.sampleBufferDisplayLayer
      guard layer.isReadyForMoreMediaData else {
        // декодер мог прерваться — сбрасываем, чтобы он ожил
        layer.flush()
        return
      }
      sample.applyRotation(frame.rotation)

      var format: CMVideoFormatDescription?
      CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &format
      )
      guard let createdFormat = format else { return }

      var timing = CMSampleTimingInfo(
        duration: CMTime.invalid,
        presentationTimeStamp: CMTime(value: CMTimeValue(frame.timeStamp), timescale: 90_000),
        decodeTimeStamp: CMTime.invalid
      )
      var sampleBuffer: CMSampleBuffer?
      CMSampleBufferCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        dataReady: true,
        makeDataReadyCallback: nil,
        refcon: nil,
        formatDescription: createdFormat,
        sampleTiming: &timing,
        sampleBufferOut: &sampleBuffer
      )
      guard let sb = sampleBuffer else { return }

      if let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) {
        let dict = (attachments as NSArray).firstObject as? NSMutableDictionary
        dict?[kCMSampleAttachmentKey_DisplayImmediately as NSString] = NSNumber(value: true)
      }
      layer.enqueue(sb)
    }
  }

  // AVPictureInPictureControllerDelegate
  func pictureInPictureControllerWillStartPictureInPicture(
    _ pipController: AVPictureInPictureController
  ) {
    shouldRender = true
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pipController: AVPictureInPictureController
  ) {
    shouldRender = false
  }

  func pictureInPictureController(
    _ pipController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    print("KometPiP: failed to start: \(error.localizedDescription)")
    shouldRender = false
  }

  func pictureInPictureController(
    _ pipController: AVPictureInPictureController,
    didTransitionToRenderSize newRenderSize: CMVideoDimensions
  ) {
    pipVideoController?.preferredContentSize = CGSize(
      width: max(CGFloat(newRenderSize.width), 1),
      height: max(CGFloat(newRenderSize.height), 1)
    )
    sampleView?.requestScaleRecalculation()
  }

  func pictureInPictureController(
    _ pipController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    completionHandler(true)
  }
}

final class SampleBufferVideoCallView: UIView {
  override class var layerClass: AnyClass {
    AVSampleBufferDisplayLayer.self
  }

  var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
    layer as! AVSampleBufferDisplayLayer
  }

  private var currentRotationDegrees: Int = -1

  // Декодированный пиксель-буфер приходит без учёта поворота — поворот
  // накладываем трансформом слоя
  func applyRotation(_ rotation: RTCVideoRotation) {
    applyDegrees(Int(rotation.rawValue))
  }

  func requestScaleRecalculation() {
    currentRotationDegrees = -1
    applyDegrees(currentRotationDegrees)
  }

  private func applyDegrees(_ degrees: Int) {
    guard degrees != currentRotationDegrees else { return }
    currentRotationDegrees = degrees
    var transform = CATransform3DIdentity
    if degrees == 90 || degrees == 270 {
      let size = bounds.size
      let scale = size.width > 0 ? size.height / size.width : 1
      transform = CATransform3DMakeScale(scale, scale, 1)
    }
    switch degrees {
    case 90:
      transform = CATransform3DRotate(transform, .pi / 2, 0, 0, 1)
    case 180:
      transform = CATransform3DRotate(transform, .pi, 0, 0, 1)
    case 270:
      transform = CATransform3DRotate(transform, 3 * .pi / 2, 0, 0, 1)
    default:
      break
    }
    sampleBufferDisplayLayer.transform = transform
  }
}

final class KometPiPContentViewController: AVPictureInPictureVideoCallViewController {
  var onLayout: (() -> Void)?

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    onLayout?()
  }
}