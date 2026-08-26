import AVFoundation
import CoreImage
import Flutter
import UIKit

private struct VideoExportSpec {
  let input: String
  let output: String
  let startMs: Int?
  let endMs: Int?
  let removeAudio: Bool
  let rotationDegrees: Double
  let flipH: Bool
  let crop: [Double]?
  let outWidth: Int
  let outHeight: Int
  let rgbMatrix: [Double]?
  let overlay: String?
  let centerSquare: Bool

  init?(_ arguments: Any?) {
    guard let args = arguments as? [String: Any],
          let input = args["input"] as? String,
          let output = args["output"] as? String else { return nil }
    self.input = input
    self.output = output
    startMs = (args["startMs"] as? NSNumber)?.intValue
    endMs = (args["endMs"] as? NSNumber)?.intValue
    removeAudio = (args["removeAudio"] as? NSNumber)?.boolValue ?? false
    rotationDegrees = (args["rotationDegrees"] as? NSNumber)?.doubleValue ?? 0
    flipH = (args["flipH"] as? NSNumber)?.boolValue ?? false
    crop = (args["crop"] as? [NSNumber])?.map { $0.doubleValue }
    outWidth = (args["outWidth"] as? NSNumber)?.intValue ?? 0
    outHeight = (args["outHeight"] as? NSNumber)?.intValue ?? 0
    rgbMatrix = (args["rgbMatrix"] as? [NSNumber])?.map { $0.doubleValue }
    overlay = args["overlay"] as? String
    centerSquare = false
  }

  init(input: String, output: String, edge: Int) {
    self.input = input
    self.output = output
    startMs = nil
    endMs = nil
    removeAudio = false
    rotationDegrees = 0
    flipH = false
    crop = nil
    outWidth = edge
    outHeight = edge
    rgbMatrix = nil
    overlay = nil
    centerSquare = true
  }
}

final class KometVideo {
  static let shared = KometVideo()

  private let queue = DispatchQueue(label: "ru.komet.app.video", qos: .userInitiated)
  private var session: AVAssetExportSession?
  private var cancelled = false

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "probe":
      probe(call.arguments, result)
    case "frames":
      frames(call.arguments, result)
    case "cropSquare":
      cropSquare(call.arguments, result)
    case "edit":
      guard let spec = VideoExportSpec(call.arguments) else {
        result(FlutterError(code: "BAD_ARGS", message: "input/output required", details: nil))
        return
      }
      export(spec) { ok in result(NSNumber(value: ok)) }
    case "editProgress":
      let value = session.map { Int(($0.progress * 100).rounded()) } ?? -1
      result(NSNumber(value: value))
    case "editCancel":
      cancelled = true
      session?.cancelExport()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func probe(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any], let input = args["input"] as? String else {
      result(FlutterError(code: "BAD_ARGS", message: "input required", details: nil))
      return
    }
    queue.async {
      let asset = AVURLAsset(url: URL(fileURLWithPath: input))
      guard let track = asset.tracks(withMediaType: .video).first else {
        Self.reply(result, nil)
        return
      }
      let size = track.naturalSize.applying(track.preferredTransform)
      let seconds = CMTimeGetSeconds(asset.duration)
      let durationMs = seconds.isFinite && seconds > 0 ? Int((seconds * 1000).rounded()) : 0
      let fps = Double(track.nominalFrameRate)
      let payload: [String: Any] = [
        "width": Int(abs(size.width).rounded()),
        "height": Int(abs(size.height).rounded()),
        "durationMs": durationMs,
        "fps": fps > 0 ? fps : 30.0,
        "hasAudio": !asset.tracks(withMediaType: .audio).isEmpty,
      ]
      Self.reply(result, payload)
    }
  }

  private func frames(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let input = args["input"] as? String,
          let times = args["times"] as? [NSNumber] else {
      result(FlutterError(code: "BAD_ARGS", message: "input/times required", details: nil))
      return
    }
    let edge = (args["size"] as? NSNumber)?.intValue ?? 256
    let precise = (args["precise"] as? NSNumber)?.boolValue ?? false
    queue.async {
      let asset = AVURLAsset(url: URL(fileURLWithPath: input))
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: edge, height: edge)
      if precise {
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
      }
      var output: [Any] = []
      for time in times {
        let at = CMTime(value: CMTimeValue(time.int64Value), timescale: 1000)
        guard let cgImage = try? generator.copyCGImage(at: at, actualTime: nil),
              let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.9) else {
          output.append(NSNull())
          continue
        }
        output.append(FlutterStandardTypedData(bytes: data))
      }
      Self.reply(result, output)
    }
  }

  private func cropSquare(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let input = args["input"] as? String,
          let output = args["output"] as? String else {
      result(FlutterError(code: "BAD_ARGS", message: "input/output required", details: nil))
      return
    }
    let edge = (args["size"] as? NSNumber)?.intValue ?? 480
    export(VideoExportSpec(input: input, output: output, edge: edge)) { ok in
      if ok {
        result(output)
      } else {
        result(FlutterError(code: "TRANSCODE_FAILED", message: "export failed", details: nil))
      }
    }
  }

  private func export(_ spec: VideoExportSpec, completion: @escaping (Bool) -> Void) {
    queue.async {
      self.cancelled = false
      let asset = AVURLAsset(url: URL(fileURLWithPath: spec.input))
      guard let videoTrack = asset.tracks(withMediaType: .video).first else {
        Self.reply { completion(false) }
        return
      }

      let totalSeconds = CMTimeGetSeconds(asset.duration)
      let start = CMTime(value: CMTimeValue(spec.startMs ?? 0), timescale: 1000)
      let endMs = spec.endMs ?? (totalSeconds.isFinite ? Int((totalSeconds * 1000).rounded()) : 0)
      let end = CMTime(value: CMTimeValue(max(endMs, spec.startMs ?? 0)), timescale: 1000)
      let range = CMTimeRange(start: start, end: end)
      guard range.duration.seconds > 0 else {
        Self.reply { completion(false) }
        return
      }

      let composition = AVMutableComposition()
      guard let compositionVideo = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        Self.reply { completion(false) }
        return
      }
      do {
        try compositionVideo.insertTimeRange(range, of: videoTrack, at: .zero)
      } catch {
        Self.reply { completion(false) }
        return
      }
      compositionVideo.preferredTransform = videoTrack.preferredTransform

      if !spec.removeAudio,
         let audioTrack = asset.tracks(withMediaType: .audio).first,
         let compositionAudio = composition.addMutableTrack(
          withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
        try? compositionAudio.insertTimeRange(range, of: audioTrack, at: .zero)
      }

      let natural = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
      let outWidth = spec.outWidth > 0 ? spec.outWidth : Int(abs(natural.width).rounded())
      let outHeight = spec.outHeight > 0 ? spec.outHeight : Int(abs(natural.height).rounded())
      guard outWidth > 0, outHeight > 0 else {
        Self.reply { completion(false) }
        return
      }

      let transform = videoTrack.preferredTransform
      let overlay = spec.overlay.flatMap { UIImage(contentsOfFile: $0) }.flatMap { CIImage(image: $0) }
      let renderSize = CGSize(width: outWidth, height: outHeight)

      let videoComposition = AVMutableVideoComposition(asset: composition) { request in
        let image = Self.render(
          request.sourceImage,
          spec: spec,
          transform: transform,
          overlay: overlay,
          renderSize: renderSize)
        request.finish(with: image, context: nil)
      }
      videoComposition.renderSize = renderSize

      let outputURL = URL(fileURLWithPath: spec.output)
      try? FileManager.default.removeItem(at: outputURL)

      guard let session = AVAssetExportSession(
        asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        Self.reply { completion(false) }
        return
      }
      session.outputURL = outputURL
      session.outputFileType = .mp4
      session.videoComposition = videoComposition
      session.shouldOptimizeForNetworkUse = true
      self.session = session

      session.exportAsynchronously {
        let ok = session.status == .completed && !self.cancelled
        self.session = nil
        if !ok { try? FileManager.default.removeItem(at: outputURL) }
        Self.reply { completion(ok) }
      }
    }
  }

  private static func render(
    _ source: CIImage,
    spec: VideoExportSpec,
    transform: CGAffineTransform,
    overlay: CIImage?,
    renderSize: CGSize
  ) -> CIImage {
    var image = normalized(source.transformed(by: transform))

    if spec.flipH {
      image = normalized(image.transformed(by: CGAffineTransform(scaleX: -1, y: 1)))
    }
    if abs(spec.rotationDegrees) > 0.01 {
      let radians = CGFloat(spec.rotationDegrees * .pi / 180)
      image = normalized(image.transformed(by: CGAffineTransform(rotationAngle: radians)))
    }
    if spec.centerSquare {
      let extent = image.extent
      let side = min(extent.width, extent.height)
      image = normalized(image.cropped(to: CGRect(
        x: extent.midX - side / 2,
        y: extent.midY - side / 2,
        width: side,
        height: side)))
    } else if let crop = spec.crop, crop.count == 4 {
      let extent = image.extent
      let left = CGFloat((crop[0] + 1) / 2)
      let right = CGFloat((crop[1] + 1) / 2)
      let bottom = CGFloat((1 - crop[2]) / 2)
      let top = CGFloat((1 - crop[3]) / 2)
      let rect = CGRect(
        x: extent.minX + left * extent.width,
        y: extent.minY + (1 - bottom) * extent.height,
        width: max(1, (right - left) * extent.width),
        height: max(1, (bottom - top) * extent.height))
      image = normalized(image.cropped(to: rect))
    }

    let extent = image.extent
    if extent.width > 0, extent.height > 0 {
      image = image.transformed(by: CGAffineTransform(
        scaleX: renderSize.width / extent.width,
        y: renderSize.height / extent.height))
      image = normalized(image)
    }

    if let matrix = spec.rgbMatrix, matrix.count == 16,
       let filter = CIFilter(name: "CIColorMatrix") {
      filter.setValue(image, forKey: kCIInputImageKey)
      filter.setValue(vector(matrix, 0, 4, 8), forKey: "inputRVector")
      filter.setValue(vector(matrix, 1, 5, 9), forKey: "inputGVector")
      filter.setValue(vector(matrix, 2, 6, 10), forKey: "inputBVector")
      filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
      filter.setValue(vector(matrix, 12, 13, 14), forKey: "inputBiasVector")
      if let output = filter.outputImage { image = output }
    }

    if let overlay = overlay {
      image = overlay.composited(over: image)
    }

    return image.cropped(to: CGRect(origin: .zero, size: renderSize))
  }

  private static func vector(_ m: [Double], _ x: Int, _ y: Int, _ z: Int) -> CIVector {
    CIVector(x: CGFloat(m[x]), y: CGFloat(m[y]), z: CGFloat(m[z]), w: 0)
  }

  private static func normalized(_ image: CIImage) -> CIImage {
    let extent = image.extent
    guard extent.origin != .zero else { return image }
    return image.transformed(
      by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y))
  }

  private static func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private static func reply(_ block: @escaping () -> Void) {
    DispatchQueue.main.async(execute: block)
  }
}
