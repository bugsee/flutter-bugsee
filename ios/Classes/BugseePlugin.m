#import <UIKit/UIKit.h>
#import "BugseePlugin.h"
#import "Bugsee/Bugsee.h"

id wrapNilIfRequired(id value) {
    if (!value) {
        return [NSNull null];
    }
    
    return value;
}

id fallbackIfNill(id value, id fallback) {
    if (!value) {
        return fallback;
    }
    
    return value;
}

id unwrapNilIfRequired(id value) {
    if (value == [NSNull null]) {
        return nil;
    }
    
    return value;
}

@implementation BugseePlugin

NSMutableSet * activeCallbacks = nil;


+ (void) registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"bugsee"
            binaryMessenger:[registrar messenger]];
  BugseePlugin* instance = [[BugseePlugin alloc] init];
  [instance setChannel:channel];
  [Bugsee sharedInstance].delegate = instance;
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype) init {
    self = [super init];
    if (self) {
        activeCallbacks = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void) handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    // construct selector for the specified method
    SEL methodSelector = NSSelectorFromString([call.method stringByAppendingString:@":result:"]);

    // get method implementation and check whether it exists
    IMP imp = [self methodForSelector:methodSelector];
    if (imp) {
        // execute method
        void (*func)(id, SEL, FlutterMethodCall*, FlutterResult) = (void *)imp;
        if (func) {
            func(self, methodSelector, call, result);
            return;
        }
    }

    // requested method was not found -> respond with error
    result(FlutterMethodNotImplemented);
}

- (BOOL) hasArgument:(NSString *)argumentName inCall:(FlutterMethodCall *)inCall {
    id value = inCall.arguments[argumentName];
    return value && (value != [NSNull null]);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Execution management
# pragma mark -
// ----------------------------------------------------------------------------------

/**
 * Launch Bugsee with the specified application token and launch options
 */
- (void) launch:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * appToken = call.arguments[@"token"];
    id launchOptions = call.arguments[@"launchOptions"];
    BugseeOptions * bugseeOptions = [self hasArgument:@"launchOptions" inCall:call] ?
        [BugseeOptions optionsFrom:launchOptions] :
        [BugseeOptions defaultOptions];

    [Bugsee launchWithToken:appToken options:bugseeOptions started:^(BOOL success){
        result([NSNumber numberWithBool:success]);
    }];
}

/**
 * Stop previously launched Bugsee instance
 */
- (void) stop:(FlutterMethodCall*)call result:(FlutterResult)result {
    [Bugsee stop:^{
        result(nil);
    }];
}

/**
 * Relaunch (i.e. stop and then launch) with the new optional launch options
 */
- (void) relaunch:(FlutterMethodCall*)call result:(FlutterResult)result {
    id launchOptions = call.arguments[@"launchOptions"];
    BugseeOptions * bugseeOptions = [self hasArgument:@"launchOptions" inCall:call] ?
        [BugseeOptions optionsFrom:launchOptions] :
        [BugseeOptions defaultOptions];

    [Bugsee relaunchWithOptions:bugseeOptions started:^(BOOL success){
        result([NSNumber numberWithBool:success]);
    }];
}

/**
 * Stop video recording
 */
- (void) pause:(FlutterMethodCall*)call result:(FlutterResult)result {
    [Bugsee pause];
    result(nil);
}

/**
 * Resume video recording
 */
- (void) resume:(FlutterMethodCall*)call result:(FlutterResult)result {
    [Bugsee resume];
    result(nil);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Events and traces
# pragma mark -
// ----------------------------------------------------------------------------------

- (void) event:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * name = call.arguments[@"name"];

    if ([self hasArgument:@"parameters" inCall:call]) {
        [Bugsee registerEvent:name withParams:call.arguments[@"parameters"]];
    } else {
        [Bugsee registerEvent:name];
    }

    result(nil);
}

- (void) trace:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * name = call.arguments[@"name"];
    id value = call.arguments[@"value"];
    [Bugsee traceKey:name withValue:value];

    result(nil);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Console
# pragma mark -
// ----------------------------------------------------------------------------------

/**
 * Log message with the specified level
 */
- (void) log:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * message = call.arguments[@"text"];
    NSUInteger level = [self hasArgument:@"level" inCall:call] ?
        [call.arguments[@"level"] integerValue] :
        BugseeLogLevelInfo;
    [Bugsee log:message level:level];
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Attributes
# pragma mark -
// ----------------------------------------------------------------------------------

/**
 *  Set user attribute by ket
 */
- (void) setAttribute:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * key = call.arguments[@"key"];
    id value = call.arguments[@"value"];
    [Bugsee setAttribute:key withValue:value];
    result(nil);
}

/**
 *  Get specific user attribute by key
 */
- (void) getAttribute:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * key = call.arguments[@"key"];
    id value = [Bugsee getAttribute:key];
    result(value);
}

/**
 *  Clear specific user attribute by key
 */
- (void) clearAttribute:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * key = call.arguments[@"key"];
    [Bugsee clearAttribute:key];
    result(nil);
}

/**
 *  Clear all user attributes
 */
- (void) clearAllAttributes:(FlutterMethodCall*)call result:(FlutterResult)result {
    [Bugsee clearAllAttributes];
    result(nil);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Email field management
# pragma mark -
// ----------------------------------------------------------------------------------

/**
 *  Set reporter's email
 */
- (void) setEmail:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * value = call.arguments[@"value"];
    [Bugsee setEmail:value];
    result(nil);
}

/**
 *  Get reporter's email
 */
- (void) getEmail:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * value = [Bugsee getEmail];
    result(value);
}

/**
 *  Clear reporter's email
 */
- (void) clearEmail:(FlutterMethodCall*)call result:(FlutterResult)result {
    [Bugsee clearEmail];
    result(nil);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Exceptions
# pragma mark -
// ----------------------------------------------------------------------------------

- (void) logException:(FlutterMethodCall*)call result:(FlutterResult)result {
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

// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Manual upload
# pragma mark -
// ----------------------------------------------------------------------------------

- (void) upload:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * summary = call.arguments[@"summary"];
    NSString * description = call.arguments[@"description"];
    NSUInteger severity = [self hasArgument:@"severity" inCall:call] ?
                    [call.arguments[@"severity"] integerValue] :
                    BugseeSeverityMedium;

    [Bugsee uploadWithSummary:summary
                  description:description
                     severity:severity];

    result(nil);
}

- (void) showReportDialog:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * summary = call.arguments[@"summary"];
    NSString * description = call.arguments[@"description"];
    NSUInteger severity = [self hasArgument:@"severity" inCall:call] ?
                    [call.arguments[@"severity"] integerValue] :
                    BugseeSeverityMedium;

    [Bugsee showReportControllerWithSummary:summary
                                description:description
                                   severity:severity];

    result(nil);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Feedback
# pragma mark -
// ----------------------------------------------------------------------------------

- (void) showFeedbackUI:(FlutterMethodCall*)call result:(FlutterResult)result {
    [Bugsee showFeedbackController];
    result(nil);
}

- (void) setDefaultFeedbackGreeting:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * greeting = call.arguments[@"greeting"];
    [Bugsee setDefaultFeedbackGreeting:greeting];
    result(nil);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Secure rectangles
# pragma mark -
// ----------------------------------------------------------------------------------

- (CGRect) getRectFromCoordsInCallArguments:(FlutterMethodCall *)call {
    double x = [call.arguments[@"x"] doubleValue];
    double y = [call.arguments[@"y"] doubleValue];
    double w = [call.arguments[@"width"] doubleValue];
    double h = [call.arguments[@"height"] doubleValue];
    return CGRectMake(x, y, w, h);
}

 /**
 *  Hides part of the screen under the Rect, maximum is 10 rects
 */
- (void) addSecureRect:(FlutterMethodCall*)call result:(FlutterResult)result {
    CGRect rect = [self getRectFromCoordsInCallArguments:call];
    [Bugsee addSecureRect:rect];
    result(nil);
}

/**
 *  Remove secure rect, if it exist
 */
- (void) removeSecureRect:(FlutterMethodCall*)call result:(FlutterResult)result {
    CGRect rect = [self getRectFromCoordsInCallArguments:call];
    [Bugsee removeSecureRect:rect];
    result(nil);
}

/**
 *  Remove all secure rects, which were previously added by [Bugsee addSecureRect:]
 */
- (void) removeAllSecureRects:(FlutterMethodCall*)call result:(FlutterResult)result {
    [Bugsee removeAllSecureRects];
    result(nil);
}

/**
 *  Get all secure rectangles
 */
- (void) getAllSecureRects:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSArray * sourceRectangles = [Bugsee getAllSecureRects];
    NSMutableArray * finalRectangles = [[NSMutableArray alloc] init];
    if (sourceRectangles) {
        finalRectangles = [NSMutableArray arrayWithCapacity:sourceRectangles.count];
        for (NSValue * rectValue in sourceRectangles) {
            CGRect sourceRect = [rectValue CGRectValue];
            NSArray * rectBounds = [NSArray arrayWithObjects:
                                    @(sourceRect.origin.x),
                                    @(sourceRect.origin.y),
                                    @(sourceRect.size.width),
                                    @(sourceRect.size.height),
                                    nil];
            [finalRectangles addObject:rectBounds];
        }
    }
    result(finalRectangles);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark View management
# pragma mark -
// ----------------------------------------------------------------------------------

- (void) setViewHidden:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSInteger viewId = [call.arguments[@"viewId"] integerValue];
    BOOL hidden = [call.arguments[@"isHidden"] boolValue];
    // TODO: get view by its ID
    // [Bugsee setView:hidden];
    result(nil);
}

- (void) isViewHidden:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSInteger viewId = [call.arguments[@"viewId"] integerValue];
    // TODO: get view by its ID
    result(nil);
}

- (void) setSecureRectsInternal:(FlutterMethodCall*)call result:(FlutterResult)result {
    // TODO: replace this with a new API which will set internal secure rectangles
    [Bugsee removeAllSecureRects];

    NSArray * boundsData = call.arguments[@"bounds"];
    
    for (int i = 0; i < boundsData.count; i += 4) {
        CGFloat x = [boundsData[i] floatValue];
        CGFloat y = [boundsData[i + 1] floatValue];
        CGFloat w = [boundsData[i + 2] floatValue];
        CGFloat h = [boundsData[i + 3] floatValue];
        [Bugsee addSecureRect:CGRectMake(x, y, w, h)];
    }

    result(nil);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark User identity
# pragma mark -
// ----------------------------------------------------------------------------------

/**
 * Adds user identification data for the current session
 */
// - (void) identifyUserWithId:(FlutterMethodCall*)call result:(FlutterResult)result {
//     NSString * userId = call.arguments[@"userId"];
//     NSString * name = call.arguments[@"name"];
//     NSString * email = call.arguments[@"email"];
//     NSString * token = call.arguments[@"token"];
//     [Bugsee identifyUserWithId:userId email:email name:name token:token];
//     result(nil);
// }

/**
 * Removes any previously set user idetification data
 */
// - (void) anonymizeUser:(FlutterMethodCall*)call result:(FlutterResult)result {
//     [Bugsee anonymizeUser];
//     result(nil);
// }


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Appearance
# pragma mark -
// ----------------------------------------------------------------------------------

- (void) setAppearanceProperty:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * colorProperty = call.arguments[@"cP"];
    NSInteger cR = [call.arguments[@"cR"] integerValue];
    NSInteger cG = [call.arguments[@"cG"] integerValue];
    NSInteger cB = [call.arguments[@"cB"] integerValue];
    NSInteger cA = [call.arguments[@"cA"] integerValue];
    UIColor * color = [UIColor colorWithRed:cR/255.0 green:cG/255.0 blue:cB/255.0 alpha:cA/255.0];
    
    [[Bugsee appearance] setValue:color forKey:colorProperty];

    result(nil);
}

- (void) getAppearanceProperty:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * colorProperty = call.arguments[@"cP"];
    
    @try {
        const UIColor * propertyColor = (UIColor *)[[Bugsee appearance] valueForKey:colorProperty];
        if (propertyColor) {
            CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
            [propertyColor getRed:&red green:&green blue:&blue alpha:&alpha];
            NSDictionary * colorMap = @{
                @"cR": @(red),
                @"cG": @(green),
                @"cB": @(blue),
                @"cA": @(alpha)
            };
            result(colorMap);
            return;
        }
    } @catch (NSException * exception) {
        NSLog(@"Bugsee: Failed to get color property value with exception: %s", exception.reason.UTF8String);
    }
    
    result(nil);
}

// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Events and callbacks
# pragma mark -
// ----------------------------------------------------------------------------------

- (void) setCallbackState:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString * callbackName = call.arguments[@"callbackName"];
    BOOL flagState = call.arguments[@"state"];

    if (flagState) {
        [activeCallbacks addObject:callbackName];
    } else {
        [activeCallbacks removeObject:callbackName];
    }

    result(nil);
}

-(void) bugseeFilterLog:(BugseeLogEvent *)log completionHandler:(BugseeLogFilterDecisionBlock)decisionBlock {
    if (![activeCallbacks containsObject:@"onLogEvent"]) {
        decisionBlock(log);
        return;
    }

    [[self channel] invokeMethod:@"onLogEvent"
                       arguments:@[[log text], @([log level])]
                          result:^(id result) {
        if (result && ![NSNull isEqual:result] && [result isKindOfClass:[NSArray class]]) {
            [log setText:result[0]];
            [log setLevel:[result[1] integerValue]];
            decisionBlock(log);
        } else {
            decisionBlock(nil);
        }
    }];
}

-(void) bugseeFilterNetworkEvent:(BugseeNetworkEvent *)event completionHandler:(BugseeNetworkFilterDecisionBlock)decisionBlock {
    if (![activeCallbacks containsObject:@"onNetworkEvent"]) {
        decisionBlock(event);
        return;
    }

    NSDictionary * eventData = @{
        @"url": fallbackIfNill(event.url, @""),
        @"body": fallbackIfNill(event.body, @""),
        @"method": fallbackIfNill(event.method, @""),
        @"stage": fallbackIfNill(event.bugseeNetworkEventType, @""),
        @"redirectUrl": fallbackIfNill(event.redirectedFromURL, @""),
        @"error":  fallbackIfNill(event.error, @{}),
        @"headers": fallbackIfNill(event.headers, @{})
    };
    
    [[self channel] invokeMethod:@"onNetworkEvent"
                       arguments:@[eventData]
                          result:^(id result) {
        if (result && ![NSNull isEqual:result] && [result isKindOfClass:[NSDictionary class]]) {
            NSDictionary * resultData = result;
            event.body = unwrapNilIfRequired([resultData objectForKey:@"body"]);
            event.url = unwrapNilIfRequired([resultData objectForKey:@"url"]);
            event.redirectedFromURL = unwrapNilIfRequired([resultData objectForKey:@"redirectUrl"]);
            event.headers = unwrapNilIfRequired([resultData objectForKey:@"headers"]);
            decisionBlock(event);
        } else {
            decisionBlock(nil);
        }
    }];
}

- (void) bugseeLifecycleEvent:(BugseeLifecycleEventType)eventType {
    [[self channel] invokeMethod:@"onLifecycleEvent" arguments:@[@(eventType)]];
}

- (void) bugseeAttachmentsForReport:(nonnull BugseeReport *)report completionHandler:(nonnull BugseeAttachmentsDecisionBlock)decisionBlock {
    if (![activeCallbacks containsObject:@"onAttachmentsForReport"]) {
        decisionBlock(nil);
        return;
    }

    [[self channel] invokeMethod:@"onAttachmentsForReport"
                       arguments:@[[report type], @([report severity])]
                          result:^(id result) {
        NSMutableArray<BugseeAttachment *> * attachments = [[NSMutableArray alloc] init];
        
        if (result && ![NSNull isEqual:result] && [result isKindOfClass:[NSArray class]]) {
           NSArray * sourceAttachments = (NSArray *)result;

           for (NSArray * entry in sourceAttachments) {
               NSString * name = ([entry[0] length] == 0 ? nil : entry[0]);
               NSString * filename = ([entry[1] length] == 0 ? name : entry[1]);
               NSData * data = nil;
               
               id rawData = entry[2];
               if ([rawData isKindOfClass:[FlutterStandardTypedData class]]) {
                   data = [rawData data];
               } else if ([rawData isKindOfClass:[NSString class]]) {
                   data = [rawData dataUsingEncoding:NSUTF8StringEncoding];
               }
               
               if (data) {
                   BugseeAttachment * attachment = [BugseeAttachment attachmentWithName:name
                                                                               filename:filename
                                                                                   data:data];
                   [attachments addObject:attachment];
               }
           }
        }

        decisionBlock(attachments);
    }];
}

-(void) bugsee:(Bugsee *)bugsee didReceiveNewFeedback:(NSArray<NSString *> *)messages {
    [[self channel] invokeMethod:@"onNewFeedbackMessages" arguments:@[messages]];
}

- (void) registerNetworkEvent:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSData * bodyData = nil;
    NSDictionary * errorData = call.arguments[@"error"] ? @{ @"errorMessage": call.arguments[@"error"] } : nil;
    NSDictionary * headers = [NSDictionary dictionaryWithDictionary:fallbackIfNill(unwrapNilIfRequired(call.arguments[@"headers"]), @{})];
    BOOL isOverride = call.arguments[@"isSupplement"] ? (BOOL)call.arguments[@"isSupplement"] == YES : NO;
    
    @try {
        NSString * stringBody = unwrapNilIfRequired(call.arguments[@"body"]);
        bodyData = [stringBody dataUsingEncoding:NSUTF8StringEncoding];
    } @catch (NSException * e) {
        // TODO: think on logging error here
    }
    
    BugseeNetworkEvent * networkEvent = [BugseeNetworkEvent eventWithID:unwrapNilIfRequired(call.arguments[@"id"])
                                                             HTTPmethod:unwrapNilIfRequired(call.arguments[@"method"])
                                                                   type:BugseeNetwork
                                                        bugseeEventType:unwrapNilIfRequired(call.arguments[@"type"])
                                                                    url:unwrapNilIfRequired(call.arguments[@"url"])
                                                          redirectedUrl:unwrapNilIfRequired(call.arguments[@"redirectUrl"])
                                                                   body:bodyData
                                                                  error:errorData
                                                                headers:headers
                                                           noBodyReason:unwrapNilIfRequired(call.arguments[@"noBodyReason"])
                                                               dataSize:[unwrapNilIfRequired(call.arguments[@"size"]) integerValue]
                                                           responseCode:[unwrapNilIfRequired(call.arguments[@"status"]) integerValue]];
    
    networkEvent.override = isOverride;

    [Bugsee registerNetworkEvent:networkEvent];

    result(nil);
}


// ----------------------------------------------------------------------------------
# pragma mark -
# pragma mark Custom logic
# pragma mark -
// ----------------------------------------------------------------------------------

/**
 *  Hides your keyboard, actualy we make it automaticaly for private fields.
 */
- (void) hideKeyboard:(FlutterMethodCall*)call result:(FlutterResult)result {
    BOOL isHidden = [call.arguments[@"isHidden"] boolValue];
    [Bugsee hideKeyboard:isHidden];
    result(nil);
}

- (void) testExceptionCrash:(FlutterMethodCall*)call result:(FlutterResult)result {
    [Bugsee testExceptionCrash];
    result(nil);
}

- (void) testSignalCrash:(FlutterMethodCall*)call result:(FlutterResult)result {
    [Bugsee testSignalCrash];
    result(nil);
}

@end
