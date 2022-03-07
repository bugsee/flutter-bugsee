/// This is a sample Flutter app  that demonstrates how to catch various kinds
/// of errors in Flutter apps and report them to Bugsee.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// This imports the Bugsee plugin
import 'package:bugsee_flutter/bugsee.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void onBugseeLifecycleEvent(BugseeLifecycleEventType e) {
  print(e);
}

Future<BugseeLogEvent> onBugseeLogEvent(BugseeLogEvent logEvent) {
  logEvent.text = "Filtered: " + logEvent.text;
  return Future.value(logEvent);
}

Future<BugseeNetworkEvent> onBugseeNetworkEvent(BugseeNetworkEvent e) {
  e.url = "<redacted>";
  return Future.value(e);
}

Future<List<BugseeAttachment>> onBugseeAttachmentsRequest(BugseeReport report) {
  var attachments = <BugseeAttachment>[];
  var list = utf8.encode("This is the contents of the attachment!");
  var data = list is Uint8List ? list : new Uint8List.fromList(list);
  attachments.add(BugseeAttachment("testAttachment", "", data));
  return Future.value(attachments);
}

Future<Null> configureBugsee() async {
  Bugsee.setLogFilter(onBugseeLogEvent);
  Bugsee.setNetworkFilter(onBugseeNetworkEvent);
  Bugsee.setLifecycleCallback(onBugseeLifecycleEvent);
  Bugsee.setAttachmentsCallback(onBugseeAttachmentsRequest);

  var bgColor = Color.fromARGB(255, 100, 150, 180);

  await Bugsee.appearance.iOS.setReportBackgroundColor(bgColor);
  await Bugsee.appearance.android.setReportBackgroundColor(bgColor);
}

BugseeLaunchOptions? createLaunchOptions() {
  if (Platform.isAndroid) {
    return new AndroidLaunchOptions();
  } else if (Platform.isIOS) {
    return new IOSLaunchOptions();
  }

  return null;
}

Future<Null> launchBugsee(Function(bool isBugseeLaunched) appRunner) async {
  var launchOptions = createLaunchOptions();
  var bugseeToken = "";

  if (Platform.isAndroid) {
    bugseeToken = "5fd1ecce-2f29-4db8-b22e-78a2ed85402d";
  } else if (Platform.isIOS) {
    bugseeToken = "a9920d8b-cb0b-43c0-a360-af68c77b5065";
  }

  await Bugsee.launch(bugseeToken,
      appRunCallback: appRunner, launchOptions: launchOptions);
}

Future<Null> main() async {
  // This is required to let Bugsee intercept network requests
  HttpOverrides.global = Bugsee.defaultHttpOverrides;

  await launchBugsee((bool isBugseeLaunched) async {
    if (isBugseeLaunched) {
      await configureBugsee();
    }
    runApp(new CrashyApp());
  });
}

class CrashyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Crashy',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Crashy'),
      ),
      body: new SingleChildScrollView(
          child: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new ElevatedButton(
              child: new Text('Dart exception'),
              onPressed: () {
                throw new StateError('This is a Dart exception.');
              },
            ),
            new ElevatedButton(
              child: new Text('async Dart exception'),
              onPressed: () async {
                foo() async {
                  throw new StateError('This is an async Dart exception.');
                }

                bar() async {
                  await foo();
                }

                await bar();
              },
            ),
            new ElevatedButton(
              child: new Text('Java exception'),
              onPressed: () async {
                Bugsee.testExceptionCrash();
              },
            ),
            new ElevatedButton(
              child: new Text('Handled exception'),
              onPressed: () async {
                try {
                  throw new FormatException('Expected at least 1 section');
                } catch (ex, st) {
                  Bugsee.logException(ex, st);
                }
              },
            ),
            new ElevatedButton(
              child: new Text('Handled empty exception'),
              onPressed: () {
                Bugsee.logException(
                    new StateError(
                        'This is a Dart exception with empty stack trace.'),
                    '');
              },
            ),
            new BugseeSecureView(
                enabled: true,
                child: new ElevatedButton(
                  child: new Text('Log messages'),
                  onPressed: () {
                    print("This is a message posted with print() call");
                    Bugsee.log("This is a test console message");
                    Bugsee.log("This is a test console ERROR message",
                        BugseeLogLevel.error);
                    Bugsee.log("This is a test console DEBUG message",
                        BugseeLogLevel.debug);
                    Bugsee.log("This is a test console INFO message",
                        BugseeLogLevel.info);
                    Bugsee.log("This is a test console WARNING message",
                        BugseeLogLevel.warning);
                  },
                )),
            new ElevatedButton(
              child: new Text('Network request'),
              onPressed: () async {
                // var httpClient = HttpClient();
                // var request = await httpClient.getUrl(
                //     Uri.parse('https://jsonplaceholder.typicode.com/posts'));
                // var response = await request.close();
                // var responseBody =
                //     await response.transform(utf8.decoder).join();

                var response = await http.post(
                  Uri.parse('https://reqres.in/api/users'),
                  headers: <String, String>{
                    'Content-Type': 'application/json; charset=UTF-8',
                  },
                  body: jsonEncode(<String, String>{
                    'title': 'Some fancy title',
                  }),
                );
                var responseBody = response.body;

                print('Received network response. Length: ' +
                    responseBody.length.toString());
              },
            ),
            new ElevatedButton(
              child: new Text('Custom events'),
              onPressed: () async {
                dynamic params = <String, dynamic>{};
                params['string'] = 'test';
                params['int'] = 5;
                params['float'] = 0.55;
                params['bool'] = true;
                Bugsee.event('event', params);
                Bugsee.trace('number', 5);
                Bugsee.trace('float', 0.55);
                Bugsee.trace('string', 'test');
                Bugsee.trace('bool', true);
                Bugsee.trace('map', params);
                Bugsee.setAttribute('age', 36);
                Bugsee.setAttribute('name', 'John Doe');
                Bugsee.setAttribute('married', false);
              },
            ),
            new ElevatedButton(
              child: new Text('Show report dialog'),
              onPressed: () {
                Bugsee.showReportDialog('Test summary', 'Test description');
              },
            ),
            new TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                )),
            new ElevatedButton(
              child: new Text('Upload report'),
              onPressed: () {
                Bugsee.upload('Test summary', 'Test description');
              },
            ),
            new ElevatedButton(
              child: new Text('Show Feedback'),
              onPressed: () {
                Bugsee.showFeedbackUI();
              },
            ),
            new ElevatedButton(
              child: new Text('Add secure rect'),
              onPressed: () {
                Bugsee.addSecureRect(new Rectangle(20, 20, 100, 100));
              },
            ),
            new ElevatedButton(
              child: new Text('Get all secure rects'),
              onPressed: () async {
                dynamic rects = await Bugsee.getAllSecureRects();
                print(rects);
              },
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
            new ElevatedButton(
              child: new Text('Dummy button'),
              onPressed: () async {},
            ),
          ],
        ),
      )),
    );
  }
}
