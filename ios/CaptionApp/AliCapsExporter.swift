import Foundation
import AVFoundation
import Photos

@objc(AliCapsExporter)
class AliCapsExporter: NSObject {
  
  @objc static func requiresMainQueueSetup() -> Bool { return false }
  
  @objc func exportVideo(
    _ videoPath: String,
    captions: [[String: Any]],
    resolution: String,
    fps: NSNumber,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    let inputURL = URL(fileURLWithPath: videoPath)
    let asset = AVURLAsset(url: inputURL)
    
    let outputSize: CGSize = resolution == "4K" ? CGSize(width: 3840, height: 2160) : CGSize(width: 1920, height: 1080)
    let fpsVal = CMTimeMake(value: 1, timescale: fps.int32Value)
    
    let composition = AVMutableComposition()
    guard
      let vTrack = asset.tracks(withMediaType: .video).first,
      let compV = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { reject("ERR", "No video track", nil); return }
    
    let dur = asset.duration
    try? compV.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: vTrack, at: .zero)
    
    if let aTrack = asset.tracks(withMediaType: .audio).first,
       let compA = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
      try? compA.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: aTrack, at: .zero)
    }
    
    // Video layer
    let videoLayer = CALayer()
    videoLayer.frame = CGRect(origin: .zero, size: outputSize)
    
    let overlayLayer = CALayer()
    overlayLayer.frame = CGRect(origin: .zero, size: outputSize)
    overlayLayer.isGeometryFlipped = true
    
    // Caption layers
    for cap in captions {
      guard let text = cap["text"] as? String,
            let start = cap["start"] as? Double,
            let end = cap["end"] as? Double else { continue }
      
      let tl = CATextLayer()
      tl.string = text
      tl.fontSize = outputSize.width / 28
      tl.foregroundColor = UIColor.white.cgColor
      tl.alignmentMode = .center
      tl.backgroundColor = UIColor(white: 0, alpha: 0.75).cgColor
      tl.cornerRadius = 8
      tl.isWrapped = true
      
      let w = outputSize.width * 0.85
      let h = outputSize.height * 0.1
      tl.frame = CGRect(x: (outputSize.width - w) / 2, y: outputSize.height * 0.08, width: w, height: h)
      tl.opacity = 0
      
      let appear = CAKeyframeAnimation(keyPath: "opacity")
      appear.values = [0, 1, 1, 0]
      appear.keyTimes = [
        NSNumber(value: max(0, start - 0.05) / CMTimeGetSeconds(dur)),
        NSNumber(value: start / CMTimeGetSeconds(dur)),
        NSNumber(value: end / CMTimeGetSeconds(dur)),
        NSNumber(value: min(1, (end + 0.05) / CMTimeGetSeconds(dur)))
      ]
      appear.duration = CMTimeGetSeconds(dur)
      appear.isRemovedOnCompletion = false
      appear.fillMode = .forwards
      tl.add(appear, forKey: "opacity")
      
      overlayLayer.addSublayer(tl)
    }
    
    let parentLayer = CALayer()
    parentLayer.frame = CGRect(origin: .zero, size: outputSize)
    parentLayer.addSublayer(videoLayer)
    parentLayer.addSublayer(overlayLayer)
    
    let videoComp = AVMutableVideoComposition()
    videoComp.frameDuration = fpsVal
    videoComp.renderSize = outputSize
    videoComp.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    
    let instr = AVMutableVideoCompositionInstruction()
    instr.timeRange = CMTimeRange(start: .zero, duration: dur)
    let layerInstr = AVMutableVideoCompositionLayerInstruction(assetTrack: compV)
    
    let scale = min(outputSize.width / vTrack.naturalSize.width, outputSize.height / vTrack.naturalSize.height)
    let tx = (outputSize.width - vTrack.naturalSize.width * scale) / 2
    let ty = (outputSize.height - vTrack.naturalSize.height * scale) / 2
    let t = vTrack.preferredTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale)).concatenating(CGAffineTransform(translationX: tx, y: ty))
    layerInstr.setTransform(t, at: .zero)
    instr.layerInstructions = [layerInstr]
    videoComp.instructions = [instr]
    
    let outURL = URL(fileURLWithPath: NSTemporaryDirectory() + "alicaps_\(Int(Date().timeIntervalSince1970)).mp4")
    
    guard let exp = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
      reject("ERR", "Cannot create exporter", nil); return
    }
    exp.outputURL = outURL
    exp.outputFileType = .mp4
    exp.videoComposition = videoComp
    
    exp.exportAsynchronously {
      if exp.status == .completed {
        PHPhotoLibrary.requestAuthorization { status in
          if status == .authorized || status == .limited {
            PHPhotoLibrary.shared().performChanges({
              PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outURL)
            }) { ok, err in
              if ok { resolve("saved") }
              else { reject("ERR", err?.localizedDescription ?? "Save failed", nil) }
            }
          } else {
            reject("ERR", "Photo library access denied", nil)
          }
        }
      } else {
        reject("ERR", exp.error?.localizedDescription ?? "Export failed", nil)
      }
    }
  }
}
