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

    // Single caption layer with keyframe animation
    CATextLayer *captionLayer = [CATextLayer layer];
    captionLayer.fontSize = outputSize.width / 22.0;
    captionLayer.foregroundColor = [UIColor whiteColor].CGColor;
    captionLayer.alignmentMode = kCAAlignmentCenter;
    captionLayer.wrapped = YES;
    captionLayer.contentsScale = 2.0;
    captionLayer.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8].CGColor;
    captionLayer.cornerRadius = 8;
    CGFloat w = outputSize.width * 0.88;
    CGFloat h = outputSize.height * 0.08;
    CGFloat y = outputSize.height * 0.06;
    captionLayer.frame = CGRectMake((outputSize.width - w) / 2.0, y, w, h);
    captionLayer.opacity = 0;
    [parentLayer addSublayer:captionLayer];

    // Build keyframe values for opacity and string
    NSMutableArray *opacityValues = [NSMutableArray array];
    NSMutableArray *opacityTimes = [NSMutableArray array];
    NSMutableArray *stringValues = [NSMutableArray array];
    NSMutableArray *stringTimes = [NSMutableArray array];

    // Start with opacity 0
    [opacityValues addObject:@0];
    [opacityTimes addObject:@0];
    [stringValues addObject:@""];
    [stringTimes addObject:@0];

    for (NSDictionary *cap in captions) {
      NSString *text = cap[@"text"];
      double start = [cap[@"start"] doubleValue];
      double end = [cap[@"end"] doubleValue];
      if (!text || text.length == 0) continue;

      double startN = start / totalDur;
      double endN = end / totalDur;

      // Show caption
      [stringValues addObject:text];
      [stringTimes addObject:@(startN)];
      [opacityValues addObject:@1];
      [opacityTimes addObject:@(startN)];

      // Hide caption
      [opacityValues addObject:@0];
      [opacityTimes addObject:@(endN)];
      [stringValues addObject:@""];
      [stringTimes addObject:@(endN)];
    }

    // End
    [opacityValues addObject:@0];
    [opacityTimes addObject:@1];

    CAKeyframeAnimation *opacityAnim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    opacityAnim.values = opacityValues;
    opacityAnim.keyTimes = opacityTimes;
    opacityAnim.duration = totalDur;
    opacityAnim.calculationMode = kCAAnimationDiscrete;
    opacityAnim.fillMode = kCAFillModeBoth;
    opacityAnim.removedOnCompletion = NO;
    [captionLayer addAnimation:opacityAnim forKey:@"opacity"];

    CAKeyframeAnimation *stringAnim = [CAKeyframeAnimation animationWithKeyPath:@"string"];
    stringAnim.values = stringValues;
    stringAnim.keyTimes = stringTimes;
    stringAnim.duration = totalDur;
    stringAnim.calculationMode = kCAAnimationDiscrete;
    stringAnim.fillMode = kCAFillModeBoth;
    stringAnim.removedOnCompletion = NO;
    [captionLayer addAnimation:stringAnim forKey:@"string"];
    
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
