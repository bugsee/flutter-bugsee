import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stack_trace/stack_trace.dart';

import 'src/appearance.dart';
import 'src/callbacks.dart';
import 'src/enums.dart';
import 'src/exceptions.dart';
import 'src/networking.dart';
import 'src/options.dart';
import 'src/state.dart';
import 'src/types.dart';
import 'src/ui.dart';
import 'src/version.dart';

export 'src/appearance.dart';
export 'src/enums.dart';
export 'src/networking.dart' show BugseeHttpOverrides;
export 'src/options.dart'
    show AndroidLaunchOptions, IOSLaunchOptions, BugseeLaunchOptions;
export 'src/types.dart';
export 'src/ui.dart' show BugseeSecureView;

typedef AppRunCallback = void Function(bool isBugseeLaunched);

class Bugsee {
  static final HttpOverrides _httpOverrides = BugseeHttpOverrides();

  static MethodChannel? _channel;
  static BugseeAppearance? _appearance;
  static BugseeExceptionHandler? _exceptionHandler;
  static BugseeCallbacks? _callbacks;
  static BugseeViewManager? _viewManager;

  static BugseeAppearance get appearance {
    _init();
    return _appearance!;
  }

  static HttpOverrides get defaultHttpOverrides => _httpOverrides;

  /// Initializes Bugsee internals
  static void _init() {
    if (_channel == null) {
      WidgetsFlutterBinding.ensureInitialized();
      _channel = const MethodChannel('bugsee');
      _appearance = BugseeAppearance(_channel!);
      _exceptionHandler = BugseeExceptionHandler(_channel!);
      _callbacks = BugseeCallbacks(_channel!);
      _viewManager = BugseeViewManager(_channel!);
    }
  }

  // ----------------------------------------------------------------------------------
  // Execution management
  // ----------------------------------------------------------------------------------

  static Future<bool> _initAndLaunch(String appToken,
      {BugseeLaunchOptions? launchOptions}) async {
    _init();
    await autoFillVersionInternal();
    // either use provided options, or fallback to explicit defaults
    setLaunchOptions(launchOptions ?? getDefaultLaunchOptions());
    var params = <String, dynamic>{
      'token': appToken,
      'launchOptions': getLaunchOptions()!.toMap(),
    };
    var launched = ((await _channel?.invokeMethod('launch', params)) ?? 0) != 0;
    if (launched) {
      _exceptionHandler?.syncWithOptions(getLaunchOptions());
      _viewManager?.startViewTracking();
    } else {
      // launch failed -> deactivate exceptions handler
      _exceptionHandler?.deactivateUnhandledInterception();
    }
    return Future.value(launched);
  }

  /// Launch Bugsee
  static Future<bool> launch(String appToken,
      {AppRunCallback? appRunCallback,
      BugseeLaunchOptions? launchOptions}) async {
    bool launched = false;

    var launchCallback = () async {
      launched = await _initAndLaunch(appToken, launchOptions: launchOptions);
      _exceptionHandler?.installGlobalErrorHandler();
    };

    if (appRunCallback != null) {
      await runZonedGuarded<FutureOr<void>>(() async {
        // Make sure we've initialized all the internals
        await launchCallback();
        appRunCallback(launched);
      }, (error, stackTrace) async {
        await Bugsee.logHandledException(error, stackTrace);
      });
    } else {
      await launchCallback();
    }

    return Future.value(launched);
  }

  /// Stop Bugsee
  static Future<void> stop() async {
    _viewManager?.stopViewTracking();
    await _channel?.invokeMethod('stop', <String, dynamic>{});
  }

  /// Relaunch (stop and launch) Bugsee with
  /// optional new launch options
  static Future<bool> relaunch([BugseeLaunchOptions? launchOptions]) async {
    var launched = false;

    if (_channel != null) {
      // either use provided options, or fallback to the initially passed
      // options
      setLaunchOptions(
          launchOptions ?? (getLaunchOptions() ?? getDefaultLaunchOptions()));
      launched = (await _channel?.invokeMethod('relaunch', <String, dynamic>{
                'launchOptions': getLaunchOptions()!.toMap(),
              }) ??
              0) !=
          0;
      if (launched) {
        _exceptionHandler?.syncWithOptions(getLaunchOptions());
        _viewManager?.startViewTracking();
      } else {
        // relaunch failed -> deactivate exceptions handler
        _exceptionHandler?.deactivateUnhandledInterception();
        _viewManager?.stopViewTracking();
      }
    }

    return Future.value(launched);
  }

  // ----------------------------------------------------------------------------------
  // Privacy
  // ----------------------------------------------------------------------------------

  /// Stop video recording (blacks out the video, but does
  /// not stop the event/data capture)
  static Future<void> pause() async {
    await _channel?.invokeMethod('pause', <String, dynamic>{});
  }

  /// Resume video capture (which was previously stopped
  /// by the call to "pause()")
  static Future<void> resume() async {
    await _channel?.invokeMethod('resume', <String, dynamic>{});
  }

  // ----------------------------------------------------------------------------------
  // Console
  // ----------------------------------------------------------------------------------

  /// Log message to the Bugsee log stream
  static Future<void> log(String text, [BugseeLogLevel? level]) async {
    await _channel?.invokeMethod('log', <String, dynamic>{
      'text': text,
      'level': (level != null) ? level.index : BugseeLogLevel.info.index
    });
  }

  /// Set callback which will be triggered when data
  /// passed to the log stream is intercepted
  static void setLogFilter(BugseeLogFilterCallback? logFilterCallback) {
    _init();
    _callbacks?.setLogFilter(logFilterCallback);
  }

  // ----------------------------------------------------------------------------------
  // Networking
  // ----------------------------------------------------------------------------------

  /// Set callback which will be triggered when network
  /// request/response is intercepted
  static void setNetworkFilter(
      BugseeNetworkFilterCallback? networkFilterCallback) {
    _init();
    _callbacks?.setNetworkFilter(networkFilterCallback);
  }

  static void registerNetworkEvent(dynamic eventData) {
    _init();
    _callbacks?.triggerNetworkFilterCallback(eventData).then((filteredEvent) {
      if (filteredEvent != null) {
        _channel?.invokeMethod('registerNetworkEvent', filteredEvent);
      }
    });
  }

  // ----------------------------------------------------------------------------------
  // Attachments
  // ----------------------------------------------------------------------------------

  static void setAttachmentsCallback(BugseeAttachmentsCallback? callback) {
    _init();
    _callbacks?.setAttachmentsCallback(callback);
  }

  // ----------------------------------------------------------------------------------
  // Events and traces
  // ----------------------------------------------------------------------------------

  static Future<Null> event(String name,
      [Map<String, dynamic>? parameters]) async {
    await _channel?.invokeMethod('event', <String, dynamic>{
      'name': name,
      'parameters': parameters,
    });
  }

  static Future<Null> trace(String name, dynamic value) async {
    await _channel?.invokeMethod('trace', <String, dynamic>{
      'name': name,
      'value': value,
    });
  }

  // ----------------------------------------------------------------------------------
  // Session identifier management
  // ----------------------------------------------------------------------------------

  static Future<Null> setEmail(String email) async {
    _init();
    await _channel?.invokeMethod('setEmail', <String, dynamic>{'value': email});
  }

  static Future<String> getEmail() async {
    _init();
    return await _channel?.invokeMethod('getEmail', <String, dynamic>{});
  }

  static Future<Null> clearEmail() async {
    _init();
    await _channel?.invokeMethod('clearEmail', <String, dynamic>{});
  }

  // ----------------------------------------------------------------------------------
  // Feedback
  // ----------------------------------------------------------------------------------

  /// Brings up the Feedback UI (aka In-App chat UI)
  static Future<void> showFeedbackUI() async {
    await _channel?.invokeMethod('showFeedbackUI', <String, dynamic>{});
  }

  /// Sets the default greeting shown in the Feedback UI (aka In-App chat UI)
  static Future<void> setDefaultFeedbackGreeting(String greeting) async {
    _init();
    await _channel?.invokeMethod(
        'setDefaultFeedbackGreeting', <String, dynamic>{'greeting': greeting});
  }

  /// Sets the callback which will be triggered when there are new
  /// feedback messages available.
  static void setNewFeedbackMessagesCallback(
      BugseeNewFeedbackMessagesCallback? callback) {
    _init();
    _callbacks?.setNewFeedbackMessagesCallback(callback);
  }

  // ----------------------------------------------------------------------------------
  // Custom attributes
  // ----------------------------------------------------------------------------------

  static Future<void> setAttribute(String key, dynamic value) async {
    _init();
    await _channel?.invokeMethod('setAttribute', <String, dynamic>{
      'key': key,
      'value': value,
    });
  }

  static Future<void> clearAttribute(String key) async {
    _init();
    await _channel?.invokeMethod('clearAttribute', <String, dynamic>{
      'key': key,
    });
  }

  static Future<dynamic> getAttribute(String key) async {
    _init();
    return await _channel?.invokeMethod('getAttribute', <String, dynamic>{
      'key': key,
    });
  }

  static Future<void> clearAllAttributes(String key) async {
    _init();
    await _channel?.invokeMethod('clearAllAttributes');
  }

  // ----------------------------------------------------------------------------------
  // Secure rectangles
  // ----------------------------------------------------------------------------------

  static Future<Null> addSecureRect(Rectangle<double> rectangle) async {
    _init();
    await _channel?.invokeMethod('addSecureRect', <String, dynamic>{
      'x': rectangle.left,
      'y': rectangle.top,
      'width': rectangle.width,
      'height': rectangle.height
    });
  }

  static Future<Null> removeSecureRect(Rectangle<double> rectangle) async {
    _init();
    await _channel?.invokeMethod('removeSecureRect', <String, dynamic>{
      'x': rectangle.left,
      'y': rectangle.top,
      'width': rectangle.width,
      'height': rectangle.height
    });
  }

  static Future<Null> removeAllSecureRects() async {
    _init();
    await _channel?.invokeMethod('removeAllSecureRects', <String, dynamic>{});
  }

  static Future<List<Rectangle<double>>?> getAllSecureRects() async {
    _init();

    List<dynamic>? rawRectangles =
        await _channel?.invokeMethod('getAllSecureRects', <String, dynamic>{});

    if (rawRectangles != null) {
      return List<Rectangle<double>>.from(
          rawRectangles.map((e) => Rectangle<double>(e[0], e[1], e[2], e[3])));
    }

    return null;
  }

  // ----------------------------------------------------------------------------------
  // Exception logging
  // ----------------------------------------------------------------------------------

  static Future<Null> logHandledException(dynamic exception,
      [dynamic stackTrace]) async {
    await _exceptionHandler?.logException(exception, true, stackTrace);
  }

  static Future<Null> logUnhandledException(dynamic exception,
      [dynamic stackTrace]) async {
    await _exceptionHandler?.logException(exception, false, stackTrace);
  }

  /// Alias for logHandledException
  static Future<Null> logException(dynamic exception,
      [dynamic stackTrace]) async {
    return logHandledException(exception, stackTrace);
  }

  static void setApplicationVersion(String version) {
    setApplicationVersionInternal(version);
  }

  // ----------------------------------------------------------------------------------
  // Manual upload
  // ----------------------------------------------------------------------------------

  /// Create and upload report silently in background. Does not bring up
  /// any UI and does not interrupt user activities in any way.
  static Future<void> upload(
      [String? summary,
      String? description,
      BugseeSeverityLevel? severity,
      List<String>? labels]) async {
    await _channel?.invokeMethod('upload', <String, dynamic>{
      'summary': summary,
      'description': description,
      'severity': severity != null ? (severity.index + 1) : null,
      'labels': labels
    });
  }

  /// Brings up the integration reporting UI (bug reporting dialog)
  /// where user should provide the details of the bug being reported.
  static Future<void> showReportDialog(
      [String? summary,
      String? description,
      BugseeSeverityLevel? severity,
      List<String>? labels]) async {
    await _channel?.invokeMethod('showReportDialog', <String, dynamic>{
      'summary': summary,
      'description': description,
      'severity': severity != null ? (severity.index + 1) : null,
      'labels': labels
    });
  }

  // ----------------------------------------------------------------------------------
  // Lifecycle
  // ----------------------------------------------------------------------------------

  /// Sets the callback which is triggered when internal Bugsee
  /// state changes
  static void setLifecycleCallback(BugseeLifecycleCallback? callback) {
    _init();
    _callbacks?.setLifecycleCallback(callback);
  }

  // ----------------------------------------------------------------------------------
  // Test crash triggers
  // ----------------------------------------------------------------------------------

  static Future<Null> testExceptionCrash() async {
    await _channel?.invokeMethod('testExceptionCrash', <String, dynamic>{});
  }

  static Future<Null> testSignalCrash() async {
    await _channel?.invokeMethod('testSignalCrash', <String, dynamic>{});
  }

  // ----------------------------------------------------------------------------------
  // Custom logic
  // ----------------------------------------------------------------------------------

  /// Wraps specified function with automatic errors and exceptions
  /// interception (using runZonedGuarded() with onError handler).
  static R? runGuarded<R>(R body(), BugseeGenericErrorCallback errorCallback) {
    return runZonedGuarded<R>(() {
      return body();
    }, (error, stackTrace) async {
      await _exceptionHandler?.logException(error, false, stackTrace);
      await errorCallback(error, stackTrace);
    });
  }

  /// Wraps specified method invocation with Chain.capture() which
  /// instructs the VM to capture longer stack traces.
  static void captureChain(dynamic body()) {
    Chain.capture(() {
      body();
    });
  }
}
