// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This is a sample Flutter app that demonstrates how to catch various kinds
/// of errors in Flutter apps and report them to Bugsee.
/// 
/// Explanations are provided in the inline comments in the code below.
library crashy;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;


// This imports the Bugsee plugin
import 'package:bugsee/bugsee.dart';

/// Whether the VM is running in debug mode.
/// 
/// This is useful to decide whether a report should be sent to Bugsee. Usually
/// reports from dev mode are not very useful, as these happen on developers'
/// workspaces rather than on users' devices in production.
bool get isInDebugMode {
  bool inDebugMode = false;
//  assert(inDebugMode = true);
  return inDebugMode;
}

// Reports [error] along with its [stackTrace] to Bugsee
Future<Null> _reportError(dynamic error, dynamic stackTrace) async {
  print('Caught error: $error');

  // Errors thrown in development mode are unlikely to be interesting. You can
  // check if you are running in dev mode using an assertion and omit sending
  // the report.
  if (isInDebugMode) {
    print(stackTrace);
    print('In dev mode. Not sending report to Bugsee.');
    return;
  }

  await Bugsee.logException(
    exception: error,
    handled: false,
    stackTrace: stackTrace,
  );
}

Future<Null> main() async {
  // This captures errors reported by the Flutter framework.
  FlutterError.onError = (FlutterErrorDetails details) async {
    if (isInDebugMode) {
      // In development mode simply print to console.
      FlutterError.dumpErrorToConsole(details);
    } else {
      // In production mode report to the application zone to report to Bugsee.
      Zone.current.handleUncaughtError(details.exception, details.stack);
    }
  };

  // This creates a [Zone] that contains the Flutter application and establishes
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
  runZonedGuarded<Future<Null>>(() async {
    runApp(new CrashyApp());
  }, (error, stackTrace) async {
    await _reportError(error, stackTrace);
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
        title: new Text('Bugsee sample app'),
      ),
      body: new SingleChildScrollView(
        child: new Center(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              new RaisedButton(
                child: new Text('Dart exception'),
                elevation: 1.0,
                onPressed: () {
                  throw new StateError('This is a Dart exception.');
                },
              ),
              new RaisedButton(
                child: new Text('Async Dart exception'),
                elevation: 1.0,
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
              new RaisedButton(
                child: new Text('Java exception'),
                elevation: 1.0,
                onPressed: () async {
                  final channel = const MethodChannel('crashy-custom-channel');
                  await channel.invokeMethod('blah');
                },
              ),
              new RaisedButton(
                child: new Text('Handled exception'),
                elevation: 1.0,
                onPressed: () async {
                  try {
                    throw new FormatException('Expected at least 1 section');
                  } catch (ex, st) {
                    Bugsee.logException(exception: ex, handled: true, stackTrace: st);
                  }
                },
              ),
              new RaisedButton(
                child: new Text('Network request'),
                elevation: 1.0,
                onPressed: () async {
                  http.get('https://jsonplaceholder.typicode.com/posts/1');
                },
              ),
              new RaisedButton(
                child: new Text('Custom data'),
                elevation: 1.0,
                onPressed: () async {
                  dynamic params = <String, dynamic>{};
                  params['string'] = 'test';
                  params['int'] = 5;
                  params['float'] = 0.55;
                  params['bool'] =  true;
                  await Bugsee.event(name: 'event', parameters: params);
                  await Bugsee.trace(name: 'number', value: 5);
                  await Bugsee.trace(name: 'float', value: 0.55);
                  await Bugsee.trace(name: 'string', value: 'test');
                  await Bugsee.trace(name: 'bool', value: true);
                  await Bugsee.trace(name: 'map', value: params);
                  await Bugsee.clearAllAttributes();
                  await Bugsee.setAttribute(key: 'age', value: 36);
                  await Bugsee.setAttribute(key: 'name', value: 'John Doe');
                  await Bugsee.setAttribute(key: 'married', value: false);
                  await Bugsee.removeAllSecureRects();
                  await Bugsee.addSecureRect(x: 0, y: 0, width: 20, height: 20);
                  await Bugsee.addSecureRect(x: 0, y: 0, width: 30, height: 30);
                  await Bugsee.removeSecureRect(x: 0, y: 0, width: 30, height: 30);
                },

              ),
              new RaisedButton(
                child: new Text('Show feedback'),
                elevation: 1.0,
                onPressed: () async {
                  Bugsee.showFeedbackUI();
                },
              ),
              new RaisedButton(
                child: new Text('Show report'),
                elevation: 1.0,
                onPressed: () async {
                  Bugsee.showPrefilledReportingUI(summary: "Test from Flutter", description: "Test description", severity: BugseeSeverityLevel.High);
                },
              ),
              new RaisedButton(
                child: new Text('Upload report'),
                elevation: 1.0,
                onPressed: () async {
                  Bugsee.upload(summary: "Test from Flutter", description: "Test description", severity: BugseeSeverityLevel.High);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}