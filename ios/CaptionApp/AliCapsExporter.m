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

    CGSize naturalSize = vTrack.naturalSize;
    CGAffineTransform txForm = vTrack.preferredTransform;
    CGSize transformedSize = CGSizeApplyAffineTransform(naturalSize, txForm);
    CGSize videoSize = CGSizeMake(ABS(transformedSize.width), ABS(transformedSize.height));
    
    CGSize outputSize;
    if ([resolution isEqualToString:@"4K"]) {
      outputSize = CGSizeMake(3840, floor(3840 * videoSize.height / videoSize.width / 2) * 2);
    } else {
      outputSize = CGSizeMake(1080, floor(1080 * videoSize.height / videoSize.width / 2) * 2);
    }

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

    CGFloat fontSize = outputSize.width / 18.0;
    CGFloat w = outputSize.width * 0.88;
    CGFloat h = outputSize.height * 0.10;
    CGFloat y = outputSize.height * 0.05;

    for (NSDictionary *cap in captions) {
      NSString *text = cap[@"text"];
      double start = [cap[@"start"] doubleValue];
      double end = [cap[@"end"] doubleValue];
      if (!text || text.length == 0) continue;
      if (end <= start) end = start + 0.5;

      CATextLayer *tl = [CATextLayer layer];
      tl.string = text;
      tl.fontSize = fontSize;
      tl.foregroundColor = [UIColor whiteColor].CGColor;
      tl.alignmentMode = kCAAlignmentCenter;
      tl.wrapped = YES;
      tl.contentsScale = 2.0;
      tl.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8].CGColor;
      tl.cornerRadius = 8;
      tl.frame = CGRectMake((outputSize.width - w) / 2.0, y, w, h);
      tl.opacity = 0;

      // Show animation: start time to end time
      CABasicAnimation *showAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
      showAnim.fromValue = @1;
      showAnim.toValue = @1;
      showAnim.beginTime = start == 0 ? 0.001 : start;
      showAnim.duration = MAX(0.1, end - start);
      showAnim.fillMode = kCAFillModeForwards;
      showAnim.removedOnCompletion = NO;
      
      // Hide animation at end
      CABasicAnimation *hideAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
      hideAnim.fromValue = @0;
      hideAnim.toValue = @0;
      hideAnim.beginTime = end;
      hideAnim.duration = totalDur - end;
      hideAnim.fillMode = kCAFillModeForwards;
      hideAnim.removedOnCompletion = NO;
      [tl addAnimation:hideAnim forKey:[NSString stringWithFormat:@"hide_%f", end]];
      [tl addAnimation:showAnim forKey:[NSString stringWithFormat:@"show_%f", start]];

      [parentLayer addSublayer:tl];
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
