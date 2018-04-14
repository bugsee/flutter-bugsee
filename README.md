# bugsee

Bugsee is a mobile SDK that adds crucial information to your bug and crash reports. Bugsee reports include video of user actions, network traffic, console logs and many other important traces from your app. Now you know what exactly led to the unexpected behavior.

Sign up for a service at https://www.bugsee.com.

## Installation

Install Bugsee plugin into your dart project by adding it to dependecies in your pubspec.yaml

```
dependencies:
  bugsee: any
```

Import Bugsee in every file you plan to call Bugsee API from:

```dart
import 'package:bugsee/bugsee.dart';
```

## Launching

Bugsee SDK has to be launched within the native part of your application

### iOS

Locate your ios/Runner/AppDelegate.m and add the following:

```objectivec
#import "Bugsee/Bugsee.h"

/// ...

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];

  [Bugsee launchWithToken:@"<YOUR APP TOKEN>"];
  
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}
```

Refer to official native iOS [documentation](https://docs.bugsee.com/sdk/ios/installation) for additional launch options.

### Android

Add native Bugsee SDK to your build.gradle:

```groovy
dependencies {
    implementation 'com.bugsee:bugsee-android:+'
}

```

If you don't have it already, create your own class for main application and make sure you extend FlutterApplication when doing so.
Launch the Bigsee SDK from there:

```java
import com.bugsee.library.Bugsee;
import java.util.HashMap;
import io.flutter.app.FlutterApplication;

public class MainApplication extends FlutterApplication {
    @Override
    public void onCreate() {
        super.onCreate();
        HashMap<String, Object> options = new HashMap<>();

        // Regular doesn't capture anything in Flutter for now
        options.put(Bugsee.Option.ExtendedVideoMode, true);
        Bugsee.launch(this, "<YOUR APP TOKEN>", options);
    }
}

```

Modify the manifest to point to this Application:

```xml
    <application
        android:name="com.acme.app.MainApplication"
        ...
```


## Custom data

### Events

Events are identified by a string and can have an optional dictionary of parameters that will be stored and passed along with the report.

```dart
// Without any additional parameters
Bugsee.event(name: payment_processed');

// ... or with additional custom parameters
Bugsee.event(name: 'payment_processed', parameters: <String, dynamic>{
                'amount': 125,
                'currency': 'USD'});
```

### Traces

Traces may be useful when you want to trace how a specific variable or state changes over time right before the problem happens.

```dart
// Manually set value of 15 to property named "credit_balance"
// any time it changes
Bugsee.trace(name: 'credit_balance', value: 15);    
```

## Manual reporting

You can register non fatal exceptions using the following method:
```dart
try {
  some_code_that_throws();
} catch (ex, st) {
  await Bugsee.logException(exception: ex, handled: true, stackTrace: st);
}
```

## Auto exception handling

Create the following method in your code:

```dart
Future<Null> _reportError(dynamic error, dynamic stackTrace) async {
  print('Caught error: $error');

  await Bugsee.logException(
    exception: error,
    handled: false,
    stackTrace: stackTrace,
  );
}
```

Hook the method to execute on Flutter errors:

```dart
// This captures errors reported by the Flutter framework.
FlutterError.onError = (FlutterErrorDetails details) async {
  // In production mode report to the application zone to report to Bugsee.
  Zone.current.handleUncaughtError(details.exception, details.stack);
};
```

Wrap your application to run in a Zone, which will catch most of the unhandled
errors automatically:

```dart
// This creates a [Zone] that contains the Flutter application and stablishes
// an error handler that captures errors and reports them.
//
// Using a zone makes sure that as many errors as possible are captured,
// including those thrown from [Timer]s, microtasks, I/O, and those forwarded
// from the `FlutterError` handler.
//
// More about zones:
//
// - https://api.dartlang.org/stable/1.24.2/dart-async/Zone-class.html
// - https://www.dartlang.org/articles/libraries/zones
runZoned<Future<Null>>(() async {
  runApp(new CrashyApp());
  }, onError: (error, stackTrace) async {
  await _reportError(error, stackTrace);
});
```

Bugsee can be further customized. For a complete SDK documentation covering additional options and API's visit [https://docs.bugsee.com/sdk/flutter](https://docs.bugsee.com/sdk/flutter)