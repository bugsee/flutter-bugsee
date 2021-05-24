#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#import "Bugsee/Bugsee.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [GeneratedPluginRegistrant registerWithRegistry:self];
    // Override point for customization after application launch.

    // [Bugsee launchWithToken:@"a9920d8b-cb0b-43c0-a360-af68c77b5065"];
    
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
