#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#import "Bugsee/Bugsee.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [GeneratedPluginRegistrant registerWithRegistry:self];
    // Override point for customization after application launch.

    [Bugsee launchWithToken:@"524872e0-8693-4961-8ec3-ed87b9313e5a"];
    
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
