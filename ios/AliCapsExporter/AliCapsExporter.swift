import AVFoundation
import UIKit
import Photos

@objc(AliCapsExporter)
class AliCapsExporter: NSObject {
  
  @objc
  func exportVideo(
    _ videoPath: String,
    captions: [[String: Any]],
    resolution: String,
    fps: NSNumber,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
    let composition = AVMutableComposition()
    
    guard
      let videoTrack = asset.tracks(withMediaType: .video).first,
      let audioTrack = asset.tracks(withMediaType: .audio).first,
      let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
      let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    else {
      rejecter("ERROR", "Could not load video tracks", nil)
      return
    }
    
    let duration = asset.duration
    try? compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
    try? compAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
    
    // Set output size
    let outputSize: CGSize
    if resolution == "4K" {
      outputSize = CGSize(width: 3840, height: 2160)
    } else {
      outputSize = CGSize(width: 1920, height: 1080)
    }
    
    let fpsValue = fps.int32Value
    
    // Video composition for captions
    let videoComposition = AVMutableVideoComposition()
    videoComposition.frameDuration = CMTime(value: 1, timescale: fpsValue)
    videoComposition.renderSize = outputSize
    
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
    
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
    
    // Scale video to output size
    let scaleX = outputSize.width / videoTrack.naturalSize.width
    let scaleY = outputSize.height / videoTrack.naturalSize.height
    let scale = min(scaleX, scaleY)
    let scaledWidth = videoTrack.naturalSize.width * scale
    let scaledHeight = videoTrack.naturalSize.height * scale
    let tx = (outputSize.width - scaledWidth) / 2
    let ty = (outputSize.height - scaledHeight) / 2
    let transform = videoTrack.preferredTransform.concatenating(
      CGAffineTransform(scaleX: scale, y: scale).concatenating(
        CGAffineTransform(translationX: tx, y: ty)
      )
    )
    layerInstruction.setTransform(transform, at: .zero)
    instruction.layerInstructions = [layerInstruction]
    videoComposition.instructions = [instruction]
    
    // Add caption layers
    let videoLayer = CALayer()
    videoLayer.frame = CGRect(origin: .zero, size: outputSize)
    
    let overlayLayer = CALayer()
    overlayLayer.frame = CGRect(origin: .zero, size: outputSize)
    
    // Add caption text layers
    for caption in captions {
      guard
        let text = caption["text"] as? String,
        let startTime = caption["start"] as? Double,
        let endTime = caption["end"] as? Double
      else { continue }
      
      let textLayer = CATextLayer()
      textLayer.string = text
      textLayer.fontSize = outputSize.width / 30
      textLayer.foregroundColor = UIColor.white.cgColor
      textLayer.alignmentMode = .center
      textLayer.backgroundColor = UIColor(white: 0, alpha: 0.7).cgColor
      textLayer.cornerRadius = 8
      
      let layerWidth = outputSize.width * 0.85
      let layerHeight = outputSize.height * 0.12
      textLayer.frame = CGRect(
        x: (outputSize.width - layerWidth) / 2,
        y: outputSize.height * 0.12,
        width: layerWidth,
        height: layerHeight
      )
      
      // Animate opacity
      let appear = CABasicAnimation(keyPath: "opacity")
      appear.fromValue = 0
      appear.toValue = 1
      appear.beginTime = startTime
      appear.duration = 0.01
      appear.fillMode = .forwards
      appear.isRemovedOnCompletion = false
      
      let disappear = CABasicAnimation(keyPath: "opacity")
      disappear.fromValue = 1
      disappear.toValue = 0
      disappear.beginTime = endTime
      disappear.duration = 0.01
      disappear.fillMode = .forwards
      disappear.isRemovedOnCompletion = false
      
      let group = CAAnimationGroup()
      group.animations = [appear, disappear]
      group.duration = CMTimeGetSeconds(duration)
      group.isRemovedOnCompletion = false
      
      textLayer.opacity = 0
      textLayer.add(group, forKey: nil)
      overlayLayer.addSublayer(textLayer)
    }
    
    let parentLayer = CALayer()
    parentLayer.frame = CGRect(origin: .zero, size: outputSize)
    parentLayer.addSublayer(videoLayer)
    parentLayer.addSublayer(overlayLayer)
    
    videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
      postProcessingAsVideoLayer: videoLayer,
      in: parentLayer
    )
    
    // Export
    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("alicaps_export_\(Date().timeIntervalSince1970).mp4")
    
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
      rejecter("ERROR", "Could not create exporter", nil)
      return
    }
    
    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    exporter.videoComposition = videoComposition
    
    exporter.exportAsynchronously {
      switch exporter.status {
      case .completed:
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
        }) { success, error in
          if success {
            resolver("Export successful")
          } else {
            rejecter("ERROR", error?.localizedDescription ?? "Save failed", nil)
          }
        }
      case .failed:
        rejecter("ERROR", exporter.error?.localizedDescription ?? "Export failed", nil)
      default:
        rejecter("ERROR", "Export cancelled", nil)
      }
    }
  }
  
  @objc
  static func requiresMainQueueSetup() -> Bool { return false }
}
