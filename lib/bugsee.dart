import 'dart:async';

import 'dart:convert';
import 'dart:ui';
import 'package:meta/meta.dart';
import 'package:flutter/services.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:crypto/crypto.dart';
import 'package:crypto/src/digest_sink.dart';
import 'bugsee-appearance.dart';

enum BugseeSeverityLevel {
  /// Low severity (lowest available)
  Low,

  /// Medium severity
  Medium,

  /// High severity
  High,

  /// Critical
  Critical,

  /// Blocker (highest available)
  Blocker
}

int _getSeverityValue(BugseeSeverityLevel severity) {
  switch (severity) {
    case BugseeSeverityLevel.Low:
      return 1;
    case BugseeSeverityLevel.Medium:
      return 2;
    case BugseeSeverityLevel.High:
      return 3;
    case BugseeSeverityLevel.Critical:
      return 4;
    case BugseeSeverityLevel.Blocker:
      return 5;
  }

  return null;
}

class Bugsee {
  static const MethodChannel _channel = const MethodChannel('bugsee');

  /// Resume previously paused Bugsee video capturing and logging interceptors
  static Future<Null> resume() async {
    await _channel.invokeMethod('pause');
  }

  /// Pause Bugsee video capturing and logging interceptors
  static Future<Null> pause() async {
    await _channel.invokeMethod('pause');
  }

  /// Log message to the Bugsee console log stream
  static Future<Null> log({@required String message}) async {
    await _channel.invokeMethod('event', <String, dynamic>{
      'message': message,
    });
  }

  /// Add user event entry
  static Future<Null> event(
      {@required String name, Map<String, dynamic> parameters}) async {
    await _channel.invokeMethod('event', <String, dynamic>{
      'name': name,
      'parameters': parameters,
    });
  }

  /// Add user trace value
  static Future<Null> trace(
      {@required String name, @required dynamic value}) async {
    await _channel.invokeMethod('trace', <String, dynamic>{
      'name': name,
      'value': value,
    });
  }

  /// Set attribute identified by [key] and its value
  static Future<Null> setAttribute(
      {@required String key, @required dynamic value}) async {
    await _channel.invokeMethod('setAttribute', <String, dynamic>{
      'key': key,
      'value': value,
    });
  }

  /// Gets the value for the specified attribute identified by [key]
  static Future<String> getAttribute({@required String key}) async {
    return await _channel.invokeMethod('getAttribute', <String, dynamic>{
      'key': key,
    });
  }

  /// Remove previously set attribute identified by [key]
  static Future<Null> clearAttribute({@required String key}) async {
    await _channel.invokeMethod('clearAttribute', <String, dynamic>{
      'key': key,
    });
  }

  /// Remove all attributes
  static Future<Null> clearAllAttributes() async {
    await _channel.invokeMethod('clearAllAttributes');
  }

  /// Set user identification string
  static Future<Null> setEmail({@required String email}) async {
    await _channel.invokeMethod('setEmail', <String, dynamic>{
      'email': email,
    });
  }

  /// Remove previously set user identification string
  static Future<Null> clearEmail() async {
    await _channel.invokeMethod('clearEmail');
  }

  /// Get previously set user identification string
  static Future<Null> getEmail() async {
    return await _channel.invokeMethod('getEmail');
  }

  /// Bring up the In-App chat UI
  static Future<Null> showFeedbackUI() async {
    return await _channel.invokeMethod('showFeedbackUI');
  }

  /// Set the default greeting message used in In-App chat (Feedback)
  static Future<Null> setDefaultFeedbackGreeting(
      {@required String greeting}) async {
    await _channel.invokeMethod('setDefaultFeedbackGreeting', <String, dynamic>{
      'greeting': greeting,
    });
  }

  static Future<Null> addSecureRect(
      {@required int x,
      @required int y,
      @required int width,
      @required int height}) async {
    await _channel.invokeMethod('addSecureRect', <String, dynamic>{
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
  }

  static Future<Null> removeSecureRect(
      {@required int x,
      @required int y,
      @required int width,
      @required int height}) async {
    await _channel.invokeMethod('removeSecureRect', <String, dynamic>{
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
  }

  static Future<Null> removeAllSecureRects() async {
    await _channel.invokeMethod('removeAllSecureRects');
  }

  static Future<List<Rect>> getAllSecureRects() async {
    // Rect.fromLTWH(left, top, width, height)
    return await _channel.invokeListMethod('getAllSecureRects');
  }

  /// Create and upload bug report with the provided [summary],
  /// [description], [severity] and [labels].
  ///
  /// All the parameters are optional.
  static Future<Null> upload(
      {String summary,
      String description,
      BugseeSeverityLevel severity,
      List<String> labels}) async {
    await _channel.invokeMethod('removeSecureRect', <String, dynamic>{
      'summary': summary,
      'description': description,
      'severity': _getSeverityValue(severity),
      'labels': labels,
    });
  }

  /// Bring up the bug reporting UI
  static Future<Null> showReportingUI() async {
    await _channel.invokeMethod('showReportingUI');
  }

  /// Bring up the bug reporting UI with the pre-filled [summary],
  /// [description], [severity] and [labels].
  ///
  /// All the parameters are optional.
  static Future<Null> showPrefilledReportingUI(
      {@required String summary,
      @required String description,
      @required BugseeSeverityLevel severity,
      List<String> labels}) async {
    await _channel.invokeMethod('showPrefilledReportingUI', <String, dynamic>{
      'summary': summary,
      'description': description,
      'severity': _getSeverityValue(severity),
      'labels': labels,
    });
  }

  /// Forcibly hide keyboard on captured video (iOS only)
  static Future<Null> hideKeyboard({@required bool hide}) async {
    return await _channel.invokeMethod('hideKeyboard', <String, dynamic>{
      'hide': hide,
    });
  }

  /// Trigger unhandled exception in native code
  static Future<Null> testNativeCrash() async {
    return await _channel.invokeMethod('testNativeCrash');
  }

  /// Log specified exception and send report to the server
  static Future<Null> logException(
      {@required dynamic exception,
      @required bool handled,
      dynamic stackTrace}) async {
    final Chain chain = stackTrace is StackTrace
        ? new Chain.forTrace(stackTrace)
        : new Chain.parse(stackTrace);

    final List<Map<String, dynamic>> frames = <Map<String, dynamic>>[];

    var ds = new DigestSink();
    var s = sha1.startChunkedConversion(ds);
    for (int t = 0; t < chain.traces.length; t += 1) {
      for (int f = 0; f < chain.traces[t].frames.length; f += 1) {
        dynamic frame = chain.traces[t].frames[f];

        dynamic uri = frame.uri;
        dynamic user = true;
        dynamic package = frame.package;

        if (frame.uri.scheme != 'dart' && frame.uri.scheme != 'package')
          uri = frame.uri.pathSegments.last;

        if (frame.uri.scheme == 'hooks' ||
            frame.uri.scheme == 'dart' ||
            frame.package == 'flutter') user = false;

        if (package == null) {
          if (frame.uri.scheme == 'dart')
            package = 'dart';
          else
            package = 'application';
        }

        frames.add(<String, dynamic>{
          'trace': '${frame.member} ($uri:${frame.line})',
          'module': '$package',
          'user': user
        });

        s.add(utf8.encode(frame.location));
      }

      if (t < chain.traces.length - 1) {
        frames.add(<String, dynamic>{
          'trace': '<asyncronous gap>',
          'module': 'dart',
          'user': false,
        });
      }
    }
    s.close();

    final dynamic ex = <String, dynamic>{
      'name': '${exception.runtimeType}',
      'reason': '$exception',
      'frames': frames,
      'signature': '${ds.value}',
    };

    await _channel.invokeMethod('logException', <String, dynamic>{
      'name': 'FlutterManagedException',
      'reason': json.encode(ex),
      'handled': handled,
      'signature': '${ds.value}',
    });
  }
}
