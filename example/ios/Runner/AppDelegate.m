#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#import "Bugsee/Bugsee.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  // Override point for customization after application launch.

  [Bugsee launchWithToken:@"dishero-ios-token"];
    
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
