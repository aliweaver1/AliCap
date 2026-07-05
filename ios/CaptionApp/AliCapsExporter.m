#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@interface AliCapsExporter : NSObject <RCTBridgeModule>
@end

@implementation AliCapsExporter

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(exportVideo:(NSString *)videoPath
                  captions:(NSArray *)captions
                  resolution:(NSString *)resolution
                  fps:(nonnull NSNumber *)fps
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSURL *inputURL = [NSURL fileURLWithPath:videoPath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:nil];
    
    CGSize outputSize = [resolution isEqualToString:@"4K"] ? CGSizeMake(3840, 2160) : CGSizeMake(1920, 1080);
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVAssetTrack *vTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    
    if (!vTrack) { reject(@"ERR", @"No video track", nil); return; }
    
    AVMutableCompositionTrack *compV = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTime dur = asset.duration;
    [compV insertTimeRange:CMTimeRangeMake(kCMTimeZero, dur) ofTrack:vTrack atTime:kCMTimeZero error:nil];
    
    AVAssetTrack *aTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (aTrack) {
      AVMutableCompositionTrack *compA = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
      [compA insertTimeRange:CMTimeRangeMake(kCMTimeZero, dur) ofTrack:aTrack atTime:kCMTimeZero error:nil];
    }
    
    // Caption layers
    CALayer *videoLayer = [CALayer layer];
    videoLayer.frame = CGRectMake(0, 0, outputSize.width, outputSize.height);
    
    CALayer *overlayLayer = [CALayer layer];
    overlayLayer.frame = CGRectMake(0, 0, outputSize.width, outputSize.height);
    overlayLayer.geometryFlipped = YES;
    
    Float64 totalDur = CMTimeGetSeconds(dur);
    
    for (NSDictionary *cap in captions) {
      NSString *text = cap[@"text"];
      double start = [cap[@"start"] doubleValue];
      double end = [cap[@"end"] doubleValue];
      if (!text || text.length == 0) continue;
      
      CATextLayer *tl = [CATextLayer layer];
      tl.string = text;
      tl.fontSize = outputSize.width / 28.0;
      tl.foregroundColor = [UIColor whiteColor].CGColor;
      tl.alignmentMode = kCAAlignmentCenter;
      tl.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75].CGColor;
      tl.cornerRadius = 8;
      tl.wrapped = YES;
      
      CGFloat w = outputSize.width * 0.85;
      CGFloat h = outputSize.height * 0.12;
      tl.frame = CGRectMake((outputSize.width - w) / 2, outputSize.height * 0.08, w, h);
      tl.opacity = 0;
      
      CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
      anim.values = @[@0, @1, @1, @0];
      anim.keyTimes = @[
        @(MAX(0, (start - 0.05) / totalDur)),
        @(start / totalDur),
        @(end / totalDur),
        @(MIN(1, (end + 0.05) / totalDur))
      ];
      anim.duration = totalDur;
      anim.removedOnCompletion = NO;
      anim.fillMode = kCAFillModeForwards;
      [tl addAnimation:anim forKey:@"opacity"];
      [overlayLayer addSublayer:tl];
    }
    
    CALayer *parentLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, outputSize.width, outputSize.height);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:overlayLayer];
    
    AVMutableVideoComposition *videoComp = [AVMutableVideoComposition videoComposition];
    videoComp.frameDuration = CMTimeMake(1, [fps intValue]);
    videoComp.renderSize = outputSize;
    videoComp.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
    AVMutableVideoCompositionInstruction *instr = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instr.timeRange = CMTimeRangeMake(kCMTimeZero, dur);
    AVMutableVideoCompositionLayerInstruction *layerInstr = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compV];
    
    CGFloat scale = MIN(outputSize.width / vTrack.naturalSize.width, outputSize.height / vTrack.naturalSize.height);
    CGFloat tx = (outputSize.width - vTrack.naturalSize.width * scale) / 2;
    CGFloat ty = (outputSize.height - vTrack.naturalSize.height * scale) / 2;
    CGAffineTransform t = CGAffineTransformConcat(vTrack.preferredTransform, CGAffineTransformConcat(CGAffineTransformMakeScale(scale, scale), CGAffineTransformMakeTranslation(tx, ty)));
    [layerInstr setTransform:t atTime:kCMTimeZero];
    instr.layerInstructions = @[layerInstr];
    videoComp.instructions = @[instr];
    
    NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"alicaps_%ld.mp4", (long)[[NSDate date] timeIntervalSince1970]]];
    NSURL *outURL = [NSURL fileURLWithPath:outPath];
    
    AVAssetExportSession *exp = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
    exp.outputURL = outURL;
    exp.outputFileType = AVFileTypeMPEG4;
    exp.videoComposition = videoComp;
    
    [exp exportAsynchronouslyWithCompletionHandler:^{
      if (exp.status == AVAssetExportSessionStatusCompleted) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
          if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
              [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outURL];
            } completionHandler:^(BOOL success, NSError *error) {
              if (success) { resolve(@"saved"); }
              else { reject(@"ERR", error.localizedDescription ?: @"Save failed", nil); }
            }];
          } else {
            reject(@"ERR", @"Photo library access denied", nil);
          }
        }];
      } else {
        reject(@"ERR", exp.error.localizedDescription ?: @"Export failed", nil);
      }
    }];
  });
}

@end
