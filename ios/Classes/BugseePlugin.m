#import "BugseePlugin.h"
#import "Bugsee/Bugsee.h"

@implementation BugseePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"bugsee"
            binaryMessenger:[registrar messenger]];
  BugseePlugin* instance = [[BugseePlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"event" isEqualToString:call.method]) {
    NSString *name = call.arguments[@"name"];
    id parameterMap = call.arguments[@"parameters"];

    if (parameterMap != [NSNull null]) {
      [Bugsee registerEvent:name withParams:parameterMap];
    } else {
      [Bugsee registerEvent:name];
    }

    result(nil);
 } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
