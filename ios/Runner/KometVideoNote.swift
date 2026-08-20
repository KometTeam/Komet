import AVFoundation
import CoreImage
import Flutter
import UIKit

final class KometVideoNoteTexture: NSObject, FlutterTexture {
  private let lock = NSLock()
  private var latest: CVPixelBuffer?

  func push(_ buffer: CVPixelBuffer) {
    lock.lock()
    latest = buffer
    lock.unlock()
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock()
    defer { lock.unlock() }
    guard let buffer = latest else { return nil }
    return Unmanaged.passRetained(buffer)
  }
}

final class KometVideoNote: NSObject {
  private let registry: FlutterTextureRegistry
  private let queue = DispatchQueue(label: "ru.komet.app.videonote", qos: .userInitiated)
  private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

  private let session = AVCaptureSession()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let audioOutput = AVCaptureAudioDataOutput()
  private let texture = KometVideoNoteTexture()

  private var textureId: Int64 = 0
  private var deviceInput: AVCaptureDeviceInput?
  private var audioInput: AVCaptureDeviceInput?
  private var position: AVCaptureDevice.Position = .front
  private var edge: Int = 480
  private var fps: Int = 30

  private var pixelBufferPool: CVPixelBufferPool?
  private var writer: AVAssetWriter?
  private var writerVideo: AVAssetWriterInput?
  private var writerAudio: AVAssetWriterInput?
  private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var outputURL: URL?
  private var recording = false
  private var sessionStarted = false

  init(registry: FlutterTextureRegistry) {
    self.registry = registry
    super.init()
  }

  static func requestPermission(_ result: @escaping FlutterResult) {
    AVCaptureDevice.requestAccess(for: .video) { video in
      guard video else {
        DispatchQueue.main.async { result(NSNumber(value: false)) }
        return
      }
      AVCaptureDevice.requestAccess(for: .audio) { audio in
        DispatchQueue.main.async { result(NSNumber(value: audio)) }
      }
    }
  }

  func initialize(front: Bool, edge: Int, fps: Int, result: @escaping FlutterResult) {
    self.position = front ? .front : .back
    self.edge = max(16, edge)
    self.fps = max(1, fps)

    queue.async {
      guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
        Self.fail(result, "NO_PERMISSION", "camera permission required")
        return
      }
      do {
        try self.configureSession()
      } catch {
        Self.fail(result, "NO_CAMERA", error.localizedDescription)
        return
      }
      self.session.startRunning()

      DispatchQueue.main.async {
        if self.textureId == 0 {
          self.textureId = self.registry.register(self.texture)
        }
        result(["textureId": NSNumber(value: self.textureId), "hasFlash": self.hasTorch()])
      }
    }
  }

  func switchCamera(result: @escaping FlutterResult) {
    queue.async {
      self.position = self.position == .front ? .back : .front
      do {
        try self.configureSession()
      } catch {
        Self.fail(result, "NO_CAMERA", error.localizedDescription)
        return
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  func setTorch(on: Bool, result: @escaping FlutterResult) {
    queue.async {
      guard let device = self.deviceInput?.device, device.hasTorch else {
        DispatchQueue.main.async { result(NSNumber(value: false)) }
        return
      }
      var applied = false
      if (try? device.lockForConfiguration()) != nil {
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        applied = on
      }
      DispatchQueue.main.async { result(NSNumber(value: applied)) }
    }
  }

  func start(result: @escaping FlutterResult) {
    queue.async {
      guard !self.recording else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      do {
        try self.prepareWriter()
      } catch {
        Self.fail(result, "START_FAILED", error.localizedDescription)
        return
      }
      self.sessionStarted = false
      self.recording = true
      DispatchQueue.main.async { result(nil) }
    }
  }

  func stop(result: @escaping FlutterResult) {
    queue.async {
      guard self.recording, let writer = self.writer else {
        Self.fail(result, "NOT_RECORDING", "no active recording")
        return
      }
      self.recording = false
      self.writerVideo?.markAsFinished()
      self.writerAudio?.markAsFinished()
      let url = self.outputURL
      writer.finishWriting {
        let ok = writer.status == .completed
        self.writer = nil
        self.writerVideo = nil
        self.writerAudio = nil
        self.adaptor = nil
        self.outputURL = nil
        let path: String? = ok ? url?.path : nil
        DispatchQueue.main.async {
          result(path)
        }
      }
    }
  }

  func dispose() {
    queue.sync {
      if self.recording {
        self.recording = false
        self.writerVideo?.markAsFinished()
        self.writerAudio?.markAsFinished()
        self.writer?.cancelWriting()
        self.writer = nil
      }
      if self.session.isRunning { self.session.stopRunning() }
      for input in self.session.inputs { self.session.removeInput(input) }
      for output in self.session.outputs { self.session.removeOutput(output) }
      self.deviceInput = nil
      self.audioInput = nil
      self.pixelBufferPool = nil
    }
    if textureId != 0 {
      registry.unregisterTexture(textureId)
      textureId = 0
    }
  }

  private func hasTorch() -> Bool {
    deviceInput?.device.hasTorch ?? false
  }

  private func configureSession() throws {
    session.beginConfiguration()
    defer { session.commitConfiguration() }

    if let existing = deviceInput {
      session.removeInput(existing)
      deviceInput = nil
    }

    guard let device = AVCaptureDevice.default(
      .builtInWideAngleCamera, for: .video, position: position)
      ?? AVCaptureDevice.default(for: .video) else {
      throw NSError(domain: "KometVideoNote", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "no camera found"])
    }
    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      throw NSError(domain: "KometVideoNote", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "camera input rejected"])
    }
    session.addInput(input)
    deviceInput = input

    if session.canSetSessionPreset(.hd1280x720) {
      session.sessionPreset = .hd1280x720
    }

    if audioInput == nil,
       let microphone = AVCaptureDevice.default(for: .audio),
       let input = try? AVCaptureDeviceInput(device: microphone),
       session.canAddInput(input) {
      session.addInput(input)
      audioInput = input
    }

    if !session.outputs.contains(videoOutput) {
      videoOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      ]
      videoOutput.alwaysDiscardsLateVideoFrames = true
      videoOutput.setSampleBufferDelegate(self, queue: queue)
      if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
    }
    if !session.outputs.contains(audioOutput) {
      audioOutput.setSampleBufferDelegate(self, queue: queue)
      if session.canAddOutput(audioOutput) { session.addOutput(audioOutput) }
    }

    if let connection = videoOutput.connection(with: .video) {
      if connection.isVideoOrientationSupported {
        connection.videoOrientation = .portrait
      }
      if connection.isVideoMirroringSupported {
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = position == .front
      }
    }

    if (try? device.lockForConfiguration()) != nil {
      let duration = CMTimeMake(value: 1, timescale: Int32(fps))
      if device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
        $0.minFrameRate <= Double(fps) && Double(fps) <= $0.maxFrameRate
      }) {
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
      }
      device.unlockForConfiguration()
    }

    pixelBufferPool = Self.makePool(edge: edge)
  }

  private func prepareWriter() throws {
    let directory = FileManager.default.temporaryDirectory
    let url = directory.appendingPathComponent(
      "komet_note_\(Int(Date().timeIntervalSince1970 * 1000)).mp4")
    try? FileManager.default.removeItem(at: url)

    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: edge,
      AVVideoHeightKey: edge,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 1_024_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      ],
    ]
    let video = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    video.expectsMediaDataInRealTime = true
    guard writer.canAdd(video) else {
      throw NSError(domain: "KometVideoNote", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "video input rejected"])
    }
    writer.add(video)

    let audioSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVNumberOfChannelsKey: 1,
      AVSampleRateKey: 44100,
      AVEncoderBitRateKey: 64000,
    ]
    let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
    audio.expectsMediaDataInRealTime = true
    if writer.canAdd(audio) { writer.add(audio) }

    adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: video,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: edge,
        kCVPixelBufferHeightKey as String: edge,
      ])

    guard writer.startWriting() else {
      throw NSError(domain: "KometVideoNote", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "writer refused to start"])
    }

    self.writer = writer
    self.writerVideo = video
    self.writerAudio = writer.inputs.contains(audio) ? audio : nil
    self.outputURL = url
  }

  private static func makePool(edge: Int) -> CVPixelBufferPool? {
    let attributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: edge,
      kCVPixelBufferHeightKey as String: edge,
      kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
    ]
    var pool: CVPixelBufferPool?
    CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool)
    return pool
  }

  private func squareBuffer(from source: CVPixelBuffer) -> CVPixelBuffer? {
    guard let pool = pixelBufferPool else { return nil }
    var target: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &target)
            == kCVReturnSuccess, let output = target else { return nil }

    let image = CIImage(cvPixelBuffer: source)
    let extent = image.extent
    let side = min(extent.width, extent.height)
    let cropped = image.cropped(to: CGRect(
      x: extent.midX - side / 2,
      y: extent.midY - side / 2,
      width: side,
      height: side))
    let scale = CGFloat(edge) / side
    let scaled = cropped
      .transformed(by: CGAffineTransform(translationX: -cropped.extent.origin.x,
                                         y: -cropped.extent.origin.y))
      .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

    ciContext.render(scaled, to: output)
    return output
  }

  private static func fail(_ result: @escaping FlutterResult, _ code: String, _ message: String) {
    DispatchQueue.main.async {
      result(FlutterError(code: code, message: message, details: nil))
    }
  }
}

extension KometVideoNote: AVCaptureVideoDataOutputSampleBufferDelegate,
                          AVCaptureAudioDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    if output === audioOutput {
      appendAudio(sampleBuffer)
      return
    }
    guard let source = CMSampleBufferGetImageBuffer(sampleBuffer),
          let square = squareBuffer(from: source) else { return }

    texture.push(square)
    let id = textureId
    if id != 0 {
      DispatchQueue.main.async { self.registry.textureFrameAvailable(id) }
    }

    guard recording, let writer = writer, let input = writerVideo,
          let adaptor = adaptor else { return }
    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    if !sessionStarted {
      writer.startSession(atSourceTime: timestamp)
      sessionStarted = true
    }
    guard input.isReadyForMoreMediaData else { return }
    adaptor.append(square, withPresentationTime: timestamp)
  }

  private func appendAudio(_ sampleBuffer: CMSampleBuffer) {
    guard recording, sessionStarted, let input = writerAudio,
          input.isReadyForMoreMediaData else { return }
    input.append(sampleBuffer)
  }
}
