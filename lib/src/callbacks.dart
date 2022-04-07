import 'dart:async';

import 'package:flutter/services.dart';

import 'enums.dart';
import 'types_internal.dart';
import 'types.dart';

class BugseeCallbacks {
  final MethodChannel _channel;

  BugseeLogFilterCallback? _logFilterCallback;
  BugseeNetworkFilterCallback? _bugseeNetworkFilterCallback;
  BugseeLifecycleCallback? _bugseeLifecycleCallback;
  BugseeAttachmentsCallback? _bugseeAttachmentsCallback;
  BugseeNewFeedbackMessagesCallback? _bugseeNewFeedbackMessagesCallback;
  BugseeAdditionalDataCaptureCallback? _bugseeAdditionalDataCaptureCallback;

  BugseeCallbacks(MethodChannel channel) : _channel = channel {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  void setLifecycleCallback(BugseeLifecycleCallback? callback) {
    _bugseeLifecycleCallback = callback;
    _setCallbackState("onLifecycleEvent", callback != null);
  }

  void setNetworkFilter(BugseeNetworkFilterCallback? callback) {
    _bugseeNetworkFilterCallback = callback;
    _setCallbackState("onNetworkEvent", callback != null);
  }

  void setLogFilter(BugseeLogFilterCallback? callback) {
    _logFilterCallback = callback;
    _setCallbackState("onLogEvent", callback != null);
  }

  void setAttachmentsCallback(BugseeAttachmentsCallback? callback) {
    _bugseeAttachmentsCallback = callback;
    _setCallbackState("onAttachmentsForReport", callback != null);
  }

  void setNewFeedbackMessagesCallback(
      BugseeNewFeedbackMessagesCallback? callback) {
    _bugseeNewFeedbackMessagesCallback = callback;
    _setCallbackState("onNewFeedbackMessages", callback != null);
  }

  void setAdditionalDataCaptureCallback(
      BugseeAdditionalDataCaptureCallback? callback) {
    _bugseeAdditionalDataCaptureCallback = callback;
  }

  Future<dynamic> triggerNetworkFilterCallback(dynamic originalEvent) async {
    if (_bugseeNetworkFilterCallback != null) {
      try {
        var wrappedEvent = BugseeNetworkEventImpl.fromRawEvent(originalEvent);
        if (wrappedEvent != null) {
          wrappedEvent = await _bugseeNetworkFilterCallback!(wrappedEvent);
          var finalValue = BugseeNetworkEventImpl.augmentAndExtendOriginalEvent(
              originalEvent, wrappedEvent);
          if (finalValue != null) {
            return Future.value(finalValue);
          } else {
            return Future.value(null);
          }
        }
      } catch (ex, st) {
        // TODO: log error here
      }
    }

    return Future.value(originalEvent);
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case "onLogEvent":
        return _onLogFilterCall(call);

      case "onNetworkEvent":
        return _onNetworkEventCall(call);

      case "onLifecycleEvent":
        return _onLifecycleEventCall(call);

      case "onAttachmentsForReport":
        return _onAttachmentsForReportCall(call);

      case "onNewFeedbackMessages":
        return _onNewFeedbackMessagesAvailableCall(call);

      case "onCaptureAdditionalData":
        return _onCaptureAdditionalData(call);

      default:
        return Future.value(null);
    }
  }

  Future<dynamic> _onNetworkEventCall(MethodCall call) async {
    return triggerNetworkFilterCallback(call.arguments[0]);
  }

  Future<dynamic> _onLogFilterCall(MethodCall call) async {
    var text = call.arguments[0];
    var level = BugseeLogLevel.values[call.arguments[1]];

    if (_logFilterCallback != null) {
      try {
        BugseeLogEvent? logEvent =
            await _logFilterCallback!(BugseeLogEvent(text, level));
        return logEvent == null
            ? null
            : Future.value([logEvent.text, logEvent.level.index]);
      } catch (ex, st) {
        // TODO: log error here
      }
    }

    return Future.value([text, level]);
  }

  Future<dynamic> _onLifecycleEventCall(MethodCall call) async {
    if (_bugseeLifecycleCallback != null) {
      _bugseeLifecycleCallback!(
          BugseeLifecycleEventType.values[call.arguments[0]]);
    }
    return Future.value(null);
  }

  Future<dynamic> _onAttachmentsForReportCall(MethodCall call) async {
    if (_bugseeAttachmentsCallback != null) {
      var report = BugseeReport(
          call.arguments[0], BugseeSeverityLevel.values[call.arguments[1] - 1]);
      var attachments = await _bugseeAttachmentsCallback!(report);
      if (attachments != null) {
        var finalAttachments =
            attachments.map((a) => [a.name, a.filename, a.data]).toList();
        return Future.value(finalAttachments);
      }
    }
    return Future.value(null);
  }

  Future<dynamic> _onNewFeedbackMessagesAvailableCall(MethodCall call) async {
    if (_bugseeNewFeedbackMessagesCallback != null) {
      _bugseeNewFeedbackMessagesCallback!(call.arguments[0]);
    }
    return Future.value(null);
  }

  Future<void> _setCallbackState(String callbackName, bool state) async {
    await _channel.invokeMethod('setCallbackState',
        <String, dynamic>{'callbackName': callbackName, 'state': state});
  }

  Future<dynamic> _onCaptureAdditionalData(MethodCall call) async {
    if (_bugseeAdditionalDataCaptureCallback != null) {
      return Future.value(
          _bugseeAdditionalDataCaptureCallback!(call.arguments[0]));
    }

    return Future.value(null);
  }
}
