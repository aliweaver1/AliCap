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
                  styleInfo:(NSDictionary *)styleInfo
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

    // Parse style info
    NSString *textColor = styleInfo[@"color"] ?: @"#FFFFFF";
    NSString *position = styleInfo[@"position"] ?: @"bottom";
    NSInteger lines = styleInfo[@"lines"] ? [styleInfo[@"lines"] integerValue] : 2;
    NSString *bgColor = styleInfo[@"bgColor"] ?: @"rgba(0,0,0,0.8)";
    
    // Convert hex color to UIColor
    UIColor *captionTextColor = [UIColor whiteColor];
    if ([textColor hasPrefix:@"#"] && textColor.length >= 7) {
      unsigned rgbValue = 0;
      NSScanner *scanner = [NSScanner scannerWithString:[textColor substringFromIndex:1]];
      [scanner scanHexInt:&rgbValue];
      captionTextColor = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0
                                         green:((rgbValue & 0x00FF00) >> 8)/255.0
                                          blue:(rgbValue & 0x0000FF)/255.0
                                         alpha:1.0];
    }
    
    // Background color
    UIColor *captionBgColor = [UIColor colorWithWhite:0 alpha:0.8];
    if ([bgColor isEqualToString:@"transparent"]) {
      captionBgColor = [UIColor clearColor];
    } else if ([bgColor hasPrefix:@"#"] && bgColor.length >= 7) {
      unsigned rgbValue = 0;
      NSScanner *scanner = [NSScanner scannerWithString:[bgColor substringFromIndex:1]];
      [scanner scanHexInt:&rgbValue];
      captionBgColor = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0
                                       green:((rgbValue & 0x00FF00) >> 8)/255.0
                                        blue:(rgbValue & 0x0000FF)/255.0
                                       alpha:1.0];
    } else if ([bgColor hasPrefix:@"rgba"]) {
      // Parse rgba(r,g,b,a)
      NSString *inner = [bgColor stringByReplacingOccurrencesOfString:@"rgba(" withString:@""];
      inner = [inner stringByReplacingOccurrencesOfString:@")" withString:@""];
      NSArray *parts = [inner componentsSeparatedByString:@","];
      if (parts.count >= 4) {
        captionBgColor = [UIColor colorWithRed:[parts[0] floatValue]/255.0
                                         green:[parts[1] floatValue]/255.0
                                          blue:[parts[2] floatValue]/255.0
                                         alpha:[parts[3] floatValue]];
      }
    }
    
    CGFloat fontSize = styleInfo[@"fontSize"] ? [styleInfo[@"fontSize"] floatValue] * (outputSize.width / 390.0) : outputSize.width / 18.0;
    CGFloat w = outputSize.width * 0.88;
    // Adjust font size based on lines to ensure proper wrapping
    if (lines == 3) {
      fontSize = fontSize * 1.7; // Bigger font for 3 lines wrapping
    } else if (lines == 2) {
      fontSize = fontSize * 0.85;
    }
    CGFloat lineHeight = fontSize * 1.6;
    CGFloat h = lineHeight * (CGFloat)lines + 40;
    CGFloat y;
    if ([position isEqualToString:@"top"]) {
      y = outputSize.height * 0.85;
    } else if ([position isEqualToString:@"middle"]) {
      y = outputSize.height * 0.45;
    } else {
      y = outputSize.height * 0.05;
    }

    for (NSDictionary *cap in captions) {
      NSString *text = cap[@"text"];
      double start = [cap[@"start"] doubleValue];
      double end = [cap[@"end"] doubleValue];
      if (!text || text.length == 0) continue;
      if (end <= start) end = start + 0.5;

      CATextLayer *tl = [CATextLayer layer];
      tl.string = text;
      tl.fontSize = fontSize;
      tl.foregroundColor = captionTextColor.CGColor;
      tl.alignmentMode = kCAAlignmentCenter;
      if (lines == 1) {
        tl.wrapped = NO;
        tl.truncationMode = kCATruncationEnd;
      } else {
        tl.wrapped = YES;
      }
      tl.contentsScale = 2.0;
      tl.backgroundColor = captionBgColor.CGColor;
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
    
    // High quality export with custom bitrate
    NSInteger targetBitrate = [resolution isEqualToString:@"4K"] ? 40000000 : 10000000; // 40Mbps for 4K, 10Mbps for 1080p
    
    NSDictionary *videoSettings = @{
      AVVideoCodecKey: AVVideoCodecTypeH264,
      AVVideoWidthKey: @(outputSize.width),
      AVVideoHeightKey: @(outputSize.height),
      AVVideoCompressionPropertiesKey: @{
        AVVideoAverageBitRateKey: @(targetBitrate),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: @([fps intValue]),
      }
    };
    
    NSDictionary *audioSettings = @{
      AVFormatIDKey: @(kAudioFormatMPEG4AAC),
      AVSampleRateKey: @44100,
      AVNumberOfChannelsKey: @2,
      AVEncoderBitRateKey: @192000,
    };
    
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
