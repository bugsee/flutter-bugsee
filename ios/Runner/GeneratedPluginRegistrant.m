//
//  Generated file. Do not edit.
//

#import "GeneratedPluginRegistrant.h"

#if __has_include(<bugsee/BugseePlugin.h>)
#import <bugsee/BugseePlugin.h>
#else
@import bugsee;
#endif

#if __has_include(<package_info/FLTPackageInfoPlugin.h>)
#import <package_info/FLTPackageInfoPlugin.h>
#else
@import package_info;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [BugseePlugin registerWithRegistrar:[registry registrarForPlugin:@"BugseePlugin"]];
  [FLTPackageInfoPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTPackageInfoPlugin"]];
}

@end
