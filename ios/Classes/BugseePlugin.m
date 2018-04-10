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
    }

    if ([@"trace" isEqualToString:call.method]) {
        NSString *name = call.arguments[@"name"];
        id value = call.arguments[@"value"];
        [Bugsee traceKey:name withValue:value];

        result(nil);
    }

    if ([@"setAttribute" isEqualToString:call.method]) {
        NSString *key = call.arguments[@"key"];
        id value = call.arguments[@"value"];

        [Bugsee setAttribute:key withValue:value];

        result(nil);
    }

    if ([@"clearAttribute" isEqualToString:call.method]) {
        NSString *key = call.arguments[@"key"];

        [Bugsee clearAttribute:key];

        result(nil);
    }

    else if ([@"logException" isEqualToString:call.method]) {
        NSString *name = call.arguments[@"name"];
        NSString *reason = call.arguments[@"reason"];
        BOOL handled = [call.arguments[@"handled"] boolValue];
        id traces = call.arguments[@"traces"];

        [Bugsee logException:name
                      reason:reason
                      frames:traces
                        type:@"flutter"
                     handled:handled];

        result(nil);
    }


    else {
        result(FlutterMethodNotImplemented);
    }
}

@end
