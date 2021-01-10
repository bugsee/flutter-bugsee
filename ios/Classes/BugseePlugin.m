#import "BugseePlugin.h"
#import "Bugsee/Bugsee.h"

@implementation BugseePlugin

static FlutterMethodChannel * channel = nil;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  channel = [FlutterMethodChannel methodChannelWithName:@"bugsee" binaryMessenger:[registrar messenger]];
  BugseePlugin * instance = [[BugseePlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"log" isEqualToString:call.method]) {
        NSString * message = call.arguments[@"message"];
        [Bugsee log:message];
        result(nil);
    }

    if ([@"event" isEqualToString:call.method]) {
        NSString * name = call.arguments[@"name"];
        id parameterMap = call.arguments[@"parameters"];
        if (parameterMap != [NSNull null]) {
            [Bugsee registerEvent:name withParams:parameterMap];
        } else {
            [Bugsee registerEvent:name];
        }
        result(nil);
    }

    if ([@"trace" isEqualToString:call.method]) {
        NSString * name = call.arguments[@"name"];
        id value = call.arguments[@"value"];
        [Bugsee traceKey:name withValue:value];
        result(nil);
    }

    if ([@"setAttribute" isEqualToString:call.method]) {
        NSString * key = call.arguments[@"key"];
        id value = call.arguments[@"value"];
        [Bugsee setAttribute:key withValue:value];
        result(nil);
    }
    if ([@"getAttribute" isEqualToString:call.method]) {
        NSString * key = call.arguments[@"key"];
        id value = [Bugsee getAttribute:key];
        result(value);
    }
    if ([@"clearAttribute" isEqualToString:call.method]) {
        NSString * key = call.arguments[@"key"];
        [Bugsee clearAttribute:key];
        result(nil);
    }
    if ([@"clearAllAttributes" isEqualToString:call.method]) {
        [Bugsee clearAllAttributes];
        result(nil);
    }

    if ([@"setEmail" isEqualToString:call.method]) {
        NSString * email = call.arguments[@"email"];
        [Bugsee setEmail:email];
        result(nil);
    }
    if ([@"clearEmail" isEqualToString:call.method]) {
        [Bugsee clearEmail];
        result(nil);
    }
    if ([@"getEmail" isEqualToString:call.method]) {
        NSString * email = [Bugsee getEmail];
        result(email);
    }

    if ([@"hideKeyboard" isEqualToString:call.method]) {
        id hideValue = call.arguments[@"hide"];
        [Bugsee hideKeyboard:(BOOL)hideValue];
        result(nil);
    }

    if ([@"setDefaultFeedbackGreeting" isEqualToString:call.method]) {
        NSString * greeting = call.arguments[@"greeting"];
        [Bugsee setDefaultFeedbackGreeting:greeting];
        result(nil);
    }
    if ([@"showFeedbackUI" isEqualToString:call.method]) {
        [Bugsee showFeedbackController];
        result(nil);
    }

    if ([@"pause" isEqualToString:call.method]) {
        [Bugsee pause];
        result(nil);
    }
    if ([@"resume" isEqualToString:call.method]) {
        [Bugsee resume];
        result(nil);
    }

    if ([@"addSecureRect" isEqualToString:call.method]) {
        NSNumber * x = call.arguments[@"x"];
        NSNumber * y = call.arguments[@"y"];
        NSNumber * width = call.arguments[@"width"];
        NSNumber * height = call.arguments[@"height"];
        CGRect rect = CGRectMake([x doubleValue], [y doubleValue], [width doubleValue], [height doubleValue]);
        [Bugsee addSecureRect:rect];
        result(nil);
    }
    if ([@"removeSecureRect" isEqualToString:call.method]) {
        NSNumber * x = call.arguments[@"x"];
        NSNumber * y = call.arguments[@"y"];
        NSNumber * width = call.arguments[@"width"];
        NSNumber * height = call.arguments[@"height"];
        CGRect rect = CGRectMake([x doubleValue], [y doubleValue], [width doubleValue], [height doubleValue]);
        [Bugsee removeSecureRect:rect];
        result(nil);
    }
    if ([@"removeAllSecureRects" isEqualToString:call.method]) {
        [Bugsee removeAllSecureRects];
        result(nil);
    }
    if ([@"getAllSecureRects" isEqualToString:call.method]) {
        NSArray * rects = [Bugsee getAllSecureRects];
        result(rects);
    }

    if ([@"upload" isEqualToString:call.method]) {
        NSString * summary = call.arguments[@"summary"];
        NSString * description = call.arguments[@"description"];
        NSNumber * severity = call.arguments[@"severity"];
        id argLabels = call.arguments[@"labels"];

        // TODO: Get default severity from launch options
        NSUInteger severityValue = (severity != nil) ? [severity unsignedIntegerValue] : 1;
        NSArray * labels = argLabels == [NSNull null] ? nil : labels;

        [Bugsee uploadWithSummary:summary description:description severity:severityValue labels:labels];

        result(nil);
    }

    if ([@"showReportingUI" isEqualToString:call.method]) {
        [Bugsee showReportController];
        result(nil);
    }
    if ([@"showPrefilledReportingUI" isEqualToString:call.method]) {
        NSString * summary = call.arguments[@"summary"];
        NSString * description = call.arguments[@"description"];
        NSNumber * severity = call.arguments[@"severity"];
        id argLabels = call.arguments[@"labels"];

        // TODO: Get default severity from launch options
        NSUInteger severityValue = (severity != nil) ? [severity unsignedIntegerValue] : 1;
        NSArray * labels = argLabels == [NSNull null] ? nil : labels;

        [Bugsee showReportControllerWithSummary:summary description:description severity:severityValue labels:labels];

        result(nil);
    }

    if ([@"testNativeCrash" isEqualToString:call.method]) {
        [Bugsee testExceptionCrash];
        result(nil);
    }

    else if ([@"logException" isEqualToString:call.method]) {
        NSString * name = call.arguments[@"name"];
        NSString * reason = call.arguments[@"reason"];
        BOOL handled = [call.arguments[@"handled"] boolValue];
        id frames = call.arguments[@"frames"];

        [Bugsee logException:name
                      reason:reason
                      frames:frames
                        type:@"flutter"
                     handled:handled];

        result(nil);
    }


    else {
        result(FlutterMethodNotImplemented);
    }
}

@end
