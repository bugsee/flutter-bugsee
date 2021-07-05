# Bugsee for flutter

Bugsee is a mobile SDK that adds crucial information to your bug and crash reports. Bugsee reports include video of user actions, network traffic, console logs and many other important traces from your app. Now you know what exactly led to the unexpected behavior.

Sign up for a service at https://www.bugsee.com.

## Installation

Install Bugsee plugin into your dart project by adding it to dependecies in your pubspec.yaml

```yaml
dependencies:
  bugsee_flutter:
    git:
      url: https://github.com/bugsee/flutter-bugsee
      # ref: 1.2.3 # if forcing a specific version by tag or branch
```

## Launching

```dart
import 'package:bugsee_flutter/bugsee.dart';

Future<Null> launchBugsee(Function(bool isBugseeLaunched) appRunner) async {
  var launchOptions;
  var bugseeToken = "";

  if (Platform.isAndroid) {
    bugseeToken = "<android app token>";
    launchOptions = new AndroidLaunchOptions();
  } else if (Platform.isIOS) {
    bugseeToken = "<ios app token>";
    launchOptions = new IOSLaunchOptions();
  }

  await Bugsee.launch(bugseeToken,
      appRunCallback: appRunner, launchOptions: launchOptions);
}

Future<Null> main() async {
  await launchBugsee((bool isBugseeLaunched) async {
    runApp(new MyApp());
  });
}

class MyApp extends StatelessWidget {
  ....
```

## Custom data

### Events

Events are identified by a string and can have an optional dictionary of parameters that will be stored and passed along with the report.

```dart
// Without any additional parameters
Bugsee.event(name: 'payment_processed');

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

Bugsee can be further customized. For a complete SDK documentation covering additional options and API's visit [https://docs.bugsee.com/sdk/flutter](https://docs.bugsee.com/sdk/flutter)
