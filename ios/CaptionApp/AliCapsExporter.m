#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AliCapsExporter, NSObject)

RCT_EXTERN_METHOD(
  exportVideo:(NSString *)videoPath
  captions:(NSArray *)captions
  resolution:(NSString *)resolution
  fps:(NSNumber *)fps
  resolve:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

@end
