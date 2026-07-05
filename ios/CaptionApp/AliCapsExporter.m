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
    AVAssetTrack *vTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!vTrack) { reject(@"ERR", @"No video track", nil); return; }

    // Use original video size - just apply transform
    CGSize naturalSize = vTrack.naturalSize;
    CGAffineTransform txForm = vTrack.preferredTransform;
    CGSize transformedSize = CGSizeApplyAffineTransform(naturalSize, txForm);
    CGSize videoSize = CGSizeMake(ABS(transformedSize.width), ABS(transformedSize.height));
    
    // Output size based on resolution keeping aspect ratio
    CGSize outputSize;
    if ([resolution isEqualToString:@"4K"]) {
      outputSize = CGSizeMake(3840, 3840 * videoSize.height / videoSize.width);
    } else {
      outputSize = CGSizeMake(1080, 1080 * videoSize.height / videoSize.width);
    }
    // Round to even numbers
    outputSize = CGSizeMake(floor(outputSize.width / 2) * 2, floor(outputSize.height / 2) * 2);

    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableCompositionTrack *compV = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTime dur = asset.duration;
    [compV insertTimeRange:CMTimeRangeMake(kCMTimeZero, dur) ofTrack:vTrack atTime:kCMTimeZero error:nil];
    
    AVAssetTrack *aTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (aTrack) {
      AVMutableCompositionTrack *compA = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
      [compA insertTimeRange:CMTimeRangeMake(kCMTimeZero, dur) ofTrack:aTrack atTime:kCMTimeZero error:nil];
    }
    
    Float64 totalDur = CMTimeGetSeconds(dur);

    CALayer *parentLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, outputSize.width, outputSize.height);
    
    CALayer *videoLayer = [CALayer layer];
    videoLayer.frame = CGRectMake(0, 0, outputSize.width, outputSize.height);
    [parentLayer addSublayer:videoLayer];
    
    CALayer *overlayLayer = [CALayer layer];
    overlayLayer.frame = CGRectMake(0, 0, outputSize.width, outputSize.height);
    overlayLayer.geometryFlipped = YES;
    [parentLayer addSublayer:overlayLayer];
    
    for (NSDictionary *cap in captions) {
      NSString *text = cap[@"text"];
      double start = [cap[@"start"] doubleValue];
      double end = [cap[@"end"] doubleValue];
      if (!text || text.length == 0) continue;
      
      CATextLayer *tl = [CATextLayer layer];
      tl.string = text;
      tl.fontSize = outputSize.width / 18.0;
      tl.foregroundColor = [UIColor whiteColor].CGColor;
      tl.alignmentMode = kCAAlignmentCenter;
      tl.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8].CGColor;
      tl.cornerRadius = 12;
      tl.wrapped = YES;
      
      CGFloat w = outputSize.width * 0.9;
      CGFloat h = outputSize.height * 0.15;
      CGFloat y = outputSize.height * 0.05;
      tl.frame = CGRectMake((outputSize.width - w) / 2, y, w, h);
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
    
    AVMutableVideoComposition *videoComp = [AVMutableVideoComposition videoComposition];
    videoComp.frameDuration = CMTimeMake(1, [fps intValue]);
    videoComp.renderSize = outputSize;
    videoComp.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
    AVMutableVideoCompositionInstruction *instr = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instr.timeRange = CMTimeRangeMake(kCMTimeZero, dur);
    AVMutableVideoCompositionLayerInstruction *layerInstr = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compV];
    
    CGFloat scale = MIN(outputSize.width / naturalSize.width, outputSize.height / naturalSize.height);
    CGFloat tx = (outputSize.width - naturalSize.width * scale) / 2;
    CGFloat ty = (outputSize.height - naturalSize.height * scale) / 2;
    CGAffineTransform t = CGAffineTransformConcat(txForm, CGAffineTransformConcat(CGAffineTransformMakeScale(scale, scale), CGAffineTransformMakeTranslation(tx, ty)));
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
