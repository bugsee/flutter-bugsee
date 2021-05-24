import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';

class BugseeAppearanceBase {
  final MethodChannel _channel;

  const BugseeAppearanceBase(MethodChannel channel) : _channel = channel;

  Future<void> _setProperty(String propertyName, Color value) async {
    await _channel.invokeMethod('setAppearanceProperty', <String, dynamic>{
      'cP': propertyName,
      'cR': value.red,
      'cG': value.green,
      'cB': value.blue,
      'cA': value.alpha,
    });
  }

  Future<Color?> _getProperty(String propertyName) async {
    dynamic rawResult = await _channel.invokeMethod('getAppearanceProperty', <String, dynamic>{
      'cP': propertyName,
    });

    if (rawResult != null) {
      Map<String, dynamic>? value = new Map<String, dynamic>.from(rawResult);
      return Color.fromARGB(value['cA'], value['cR'], value['cG'], value['cB']);
    }

    return null;
  }
}

class BugseeAppearanceIOS extends BugseeAppearanceBase {
  const BugseeAppearanceIOS(MethodChannel channel) : super(channel);

  Future<Color?> get reportCellBackgroundColor =>
      _getProperty('reportCellBackgroundColor');
  Future<Null> setReportCellBackgroundColor(Color value) async {
    await _setProperty('reportCellBackgroundColor', value);
  }

  Future<Color?> get reportVersionColor => _getProperty('reportVersionColor');
  Future<Null> setReportVersionColor(Color value) async {
    await _setProperty('reportVersionColor', value);
  }

  Future<Color?> get reportTextColor => _getProperty('reportTextColor');
  Future<Null> setReportTextColor(Color value) async {
    await _setProperty('reportTextColor', value);
  }

  Future<Color?> get reportSendButtonColor =>
      _getProperty('reportSendButtonColor');
  Future<Null> setReportSendButtonColor(Color value) async {
    await _setProperty('reportSendButtonColor', value);
  }

  Future<Color?> get reportPlaceholderColor =>
      _getProperty('reportPlaceholderColor');
  Future<Null> setReportPlaceholderColor(Color value) async {
    await _setProperty('reportPlaceholderColor', value);
  }

  Future<Color?> get reportNavigationBarColor =>
      _getProperty('reportNavigationBarColor');
  Future<Null> setReportNavigationBarColor(Color value) async {
    await _setProperty('reportNavigationBarColor', value);
  }

  Future<Color?> get reportBackgroundColor =>
      _getProperty('reportBackgroundColor');
  Future<Null> setReportBackgroundColor(Color value) async {
    await _setProperty('reportBackgroundColor', value);
  }

  Future<Color?> get reportCloseButtonColor =>
      _getProperty('reportCloseButtonColor');
  Future<Null> setReportCloseButtonColor(Color value) async {
    await _setProperty('reportCloseButtonColor', value);
  }

  Future<Color?> get feedbackBarsColor => _getProperty('feedbackBarsColor');
  Future<Null> setFeedbackBarsColor(Color value) async {
    await _setProperty('feedbackBarsColor', value);
  }

  Future<Color?> get feedbackBackgroundColor =>
      _getProperty('feedbackBackgroundColor');
  Future<Null> setFeedbackBackgroundColor(Color value) async {
    await _setProperty('feedbackBackgroundColor', value);
  }

  Future<Color?> get feedbackIncomingBubbleColor =>
      _getProperty('feedbackIncomingBubbleColor');
  Future<Null> setFeedbackIncomingBubbleColor(Color value) async {
    await _setProperty('feedbackIncomingBubbleColor', value);
  }

  Future<Color?> get feedbackOutgoingBubbleColor =>
      _getProperty('feedbackOutgoingBubbleColor');
  Future<Null> setFeedbackOutgoingBubbleColor(Color value) async {
    await _setProperty('feedbackOutgoingBubbleColor', value);
  }

  Future<Color?> get feedbackIncomingTextColor =>
      _getProperty('feedbackIncomingTextColor');
  Future<Null> setFeedbackIncomingTextColor(Color value) async {
    await _setProperty('feedbackIncomingTextColor', value);
  }

  Future<Color?> get feedbackOutgoingTextColor =>
      _getProperty('feedbackOutgoingTextColor');
  Future<Null> setFeedbackOutgoingTextColor(Color value) async {
    await _setProperty('feedbackOutgoingTextColor', value);
  }

  Future<Color?> get feedbackTitleTextColor =>
      _getProperty('feedbackTitleTextColor');
  Future<Null> setFeedbackTitleTextColor(Color value) async {
    await _setProperty('feedbackTitleTextColor', value);
  }

  Future<Color?> get feedbackEmailSkipColor =>
      _getProperty('feedbackEmailSkipColor');
  Future<Null> setFeedbackEmailSkipColor(Color value) async {
    await _setProperty('feedbackEmailSkipColor', value);
  }

  Future<Color?> get feedbackEmailBackgroundColor =>
      _getProperty('feedbackEmailBackgroundColor');
  Future<Null> setFeedbackEmailBackgroundColor(Color value) async {
    await _setProperty('feedbackEmailBackgroundColor', value);
  }

  Future<Color?> get feedbackEmailContinueNotActiveColor =>
      _getProperty('feedbackEmailContinueNotActiveColor');
  Future<Null> setFeedbackEmailContinueNotActiveColor(Color value) async {
    await _setProperty('feedbackEmailContinueNotActiveColor', value);
  }

  Future<Color?> get feedbackEmailContinueActiveColor =>
      _getProperty('feedbackEmailContinueActiveColor');
  Future<Null> setFeedbackEmailContinueActiveColor(Color value) async {
    await _setProperty('feedbackEmailContinueActiveColor', value);
  }

  Future<Color?> get feedbackInputTextColor =>
      _getProperty('feedbackInputTextColor');
  Future<Null> setFeedbackInputTextColor(Color value) async {
    await _setProperty('feedbackInputTextColor', value);
  }

  Future<Color?> get feedbackInputBackgroundColor =>
      _getProperty('feedbackInputBackgroundColor');
  Future<Null> setFeedbackInputBackgroundColor(Color value) async {
    await _setProperty('feedbackInputBackgroundColor', value);
  }

  Future<Color?> get feedbackCloseButtonColor =>
      _getProperty('feedbackCloseButtonColor');
  Future<Null> setFeedbackCloseButtonColor(Color value) async {
    await _setProperty('feedbackCloseButtonColor', value);
  }

  Future<Color?> get feedbackNavigationBarColor =>
      _getProperty('feedbackNavigationBarColor');
  Future<Null> setFeedbackNavigationBarColor(Color value) async {
    await _setProperty('feedbackNavigationBarColor', value);
  }
}

class BugseeAppearanceAndroid extends BugseeAppearanceBase {
  const BugseeAppearanceAndroid(MethodChannel channel) : super(channel);

  Future<Color?> get reportActionBarColor =>
      _getProperty('ReportActionBarColor');
  Future<Null> setReportActionBarColor(Color value) async {
    await _setProperty('ReportActionBarColor', value);
  }

  Future<Color?> get reportEditTextBackgroundColor =>
      _getProperty('ReportEditTextBackgroundColor');
  Future<Null> setReportEditTextBackgroundColor(Color value) async {
    await _setProperty('ReportEditTextBackgroundColor', value);
  }

  Future<Color?> get reportVersionColor =>
      _getProperty('ReportVersionColor');
  Future<Null> setReportVersionColor(Color value) async {
    await _setProperty('ReportVersionColor', value);
  }

  Future<Color?> get reportTextColor =>
      _getProperty('ReportTextColor');
  Future<Null> setReportTextColor(Color value) async {
    await _setProperty('ReportTextColor', value);
  }

  Future<Color?> get reportHintColor =>
      _getProperty('ReportHintColor');
  Future<Null> setReportHintColor(Color value) async {
    await _setProperty('ReportHintColor', value);
  }

  Future<Color?> get reportActionBarTextColor =>
      _getProperty('ReportActionBarTextColor');
  Future<Null> setReportActionBarTextColor(Color value) async {
    await _setProperty('ReportActionBarTextColor', value);
  }

  Future<Color?> get reportActionBarButtonBackgroundClickedColor =>
      _getProperty('ReportActionBarButtonBackgroundClickedColor');
  Future<Null> setReportActionBarButtonBackgroundClickedColor(Color value) async {
    await _setProperty('ReportActionBarButtonBackgroundClickedColor', value);
  }

  Future<Color?> get reportBackgroundColor =>
      _getProperty('ReportBackgroundColor');
  Future<Null> setReportBackgroundColor(Color value) async {
    await _setProperty('ReportBackgroundColor', value);
  }

  Future<Color?> get reportSeverityLabelActiveColor =>
      _getProperty('ReportSeverityLabelActiveColor');
  Future<Null> setReportSeverityLabelActiveColor(Color value) async {
    await _setProperty('ReportSeverityLabelActiveColor', value);
  }

  Future<Color?> get feedbackActionBarColor =>
      _getProperty('FeedbackActionBarColor');
  Future<Null> setFeedbackActionBarColor(Color value) async {
    await _setProperty('FeedbackActionBarColor', value);
  }

  Future<Color?> get feedbackBackgroundColor =>
      _getProperty('FeedbackBackgroundColor');
  Future<Null> setFeedbackBackgroundColor(Color value) async {
    await _setProperty('FeedbackBackgroundColor', value);
  }

  Future<Color?> get feedbackActionBarButtonBackgroundClickedColor =>
      _getProperty('FeedbackActionBarButtonBackgroundClickedColor');
  Future<Null> setFeedbackActionBarButtonBackgroundClickedColor(Color value) async {
    await _setProperty('FeedbackActionBarButtonBackgroundClickedColor', value);
  }

  Future<Color?> get feedbackIncomingBubbleColor =>
      _getProperty('FeedbackIncomingBubbleColor');
  Future<Null> setFeedbackIncomingBubbleColor(Color value) async {
    await _setProperty('FeedbackIncomingBubbleColor', value);
  }

  Future<Color?> get feedbackOutgoingBubbleColor =>
      _getProperty('FeedbackOutgoingBubbleColor');
  Future<Null> setFeedbackOutgoingBubbleColor(Color value) async {
    await _setProperty('FeedbackOutgoingBubbleColor', value);
  }

  Future<Color?> get feedbackIncomingTextColor =>
      _getProperty('FeedbackIncomingTextColor');
  Future<Null> setFeedbackIncomingTextColor(Color value) async {
    await _setProperty('FeedbackIncomingTextColor', value);
  }

  Future<Color?> get feedbackOutgoingTextColor =>
      _getProperty('FeedbackOutgoingTextColor');
  Future<Null> setFeedbackOutgoingTextColor(Color value) async {
    await _setProperty('FeedbackOutgoingTextColor', value);
  }

  Future<Color?> get feedbackDateTextColor =>
      _getProperty('FeedbackDateTextColor');
  Future<Null> setFeedbackDateTextColor(Color value) async {
    await _setProperty('FeedbackDateTextColor', value);
  }

  Future<Color?> get feedbackTitleTextColor =>
      _getProperty('FeedbackTitleTextColor');
  Future<Null> setFeedbackTitleTextColor(Color value) async {
    await _setProperty('FeedbackTitleTextColor', value);
  }

  Future<Color?> get feedbackEmailSkipTextColor =>
      _getProperty('FeedbackEmailSkipTextColor');
  Future<Null> setFeedbackEmailSkipTextColor(Color value) async {
    await _setProperty('FeedbackEmailSkipTextColor', value);
  }

  Future<Color?> get feedbackEmailSkipBackgroundClickedColor =>
      _getProperty('FeedbackEmailSkipBackgroundClickedColor');
  Future<Null> setFeedbackEmailSkipBackgroundClickedColor(Color value) async {
    await _setProperty('FeedbackEmailSkipBackgroundClickedColor', value);
  }

  Future<Color?> get feedbackEmailBackgroundColor =>
      _getProperty('FeedbackEmailBackgroundColor');
  Future<Null> setFeedbackEmailBackgroundColor(Color value) async {
    await _setProperty('FeedbackEmailBackgroundColor', value);
  }

  Future<Color?> get feedbackEmailContinueNotActiveColor =>
      _getProperty('FeedbackEmailContinueNotActiveColor');
  Future<Null> setFeedbackEmailContinueNotActiveColor(Color value) async {
    await _setProperty('FeedbackEmailContinueNotActiveColor', value);
  }

  Future<Color?> get feedbackEmailContinueActiveColor =>
      _getProperty('FeedbackEmailContinueActiveColor');
  Future<Null> setFeedbackEmailContinueActiveColor(Color value) async {
    await _setProperty('FeedbackEmailContinueActiveColor', value);
  }

  Future<Color?> get feedbackEmailContinueClickedColor =>
      _getProperty('FeedbackEmailContinueClickedColor');
  Future<Null> setFeedbackEmailContinueClickedColor(Color value) async {
    await _setProperty('FeedbackEmailContinueClickedColor', value);
  }

  Future<Color?> get feedbackInputTextColor =>
      _getProperty('FeedbackInputTextColor');
  Future<Null> setFeedbackInputTextColor(Color value) async {
    await _setProperty('FeedbackInputTextColor', value);
  }

  Future<Color?> get feedbackInputTextHintColor =>
      _getProperty('FeedbackInputTextHintColor');
  Future<Null> setFeedbackInputTextHintColor(Color value) async {
    await _setProperty('FeedbackInputTextHintColor', value);
  }

  Future<Color?> get feedbackBottomDelimiterColor =>
      _getProperty('FeedbackBottomDelimiterColor');
  Future<Null> setFeedbackBottomDelimiterColor(Color value) async {
    await _setProperty('FeedbackBottomDelimiterColor', value);
  }

  Future<Color?> get feedbackLoadingBarBackgroundColor =>
      _getProperty('FeedbackLoadingBarBackgroundColor');
  Future<Null> setFeedbackLoadingBarBackgroundColor(Color value) async {
    await _setProperty('FeedbackLoadingBarBackgroundColor', value);
  }

  Future<Color?> get feedbackLoadingTextColor =>
      _getProperty('FeedbackLoadingTextColor');
  Future<Null> setFeedbackLoadingTextColor(Color value) async {
    await _setProperty('FeedbackLoadingTextColor', value);
  }

  Future<Color?> get feedbackErrorTextColor =>
      _getProperty('FeedbackErrorTextColor');
  Future<Null> setFeedbackErrorTextColor(Color value) async {
    await _setProperty('FeedbackErrorTextColor', value);
  }

  Future<Color?> get feedbackVersionChangedBackgroundColor =>
      _getProperty('FeedbackVersionChangedBackgroundColor');
  Future<Null> setFeedbackVersionChangedBackgroundColor(Color value) async {
    await _setProperty('FeedbackVersionChangedBackgroundColor', value);
  }

  Future<Color?> get feedbackVersionChangedTextColor =>
      _getProperty('FeedbackVersionChangedTextColor');
  Future<Null> setFeedbackVersionChangedTextColor(Color value) async {
    await _setProperty('FeedbackVersionChangedTextColor', value);
  }
}

class BugseeAppearance {
  final BugseeAppearanceAndroid _androidAppearance;
  final BugseeAppearanceIOS _iosAppearance;

  BugseeAppearance._(this._androidAppearance, this._iosAppearance);

  factory BugseeAppearance(MethodChannel channel) {
    return new BugseeAppearance._(BugseeAppearanceAndroid(channel), BugseeAppearanceIOS(channel));
  }

  BugseeAppearanceAndroid get android => _androidAppearance;
  BugseeAppearanceIOS get iOS => _iosAppearance;
}
