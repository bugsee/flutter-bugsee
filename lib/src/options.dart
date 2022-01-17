import 'dart:io' show Platform;
import 'dart:math';

import 'enums.dart';
import 'version.dart';

const MAX_BODY_LENGTH = 5 * 1024;

/// Base launch options class
abstract class BugseeLaunchOptions {
  final Map<String, dynamic> _optionsMap = new Map<String, dynamic>();

  Map<String, dynamic> toMap() {
    return new Map<String, dynamic>.from(_optionsMap);
  }

  operator [](index) => _optionsMap[index];
  operator []=(index, value) {
    _optionsMap[index] = value;
  }

  void setDefaults() {
    // set wrapper info
    _optionsMap['wrapper_info'] = {
      'type': 'flutter',
      'version': BUGSEE_VERSION,
      'build': '0'
    };

    maxRecordingTime = 60;
    shakeToReport = true;
    crashReport = true;
    videoEnabled = true;
    videoScale = 1.0;
    captureLogs = true;
    monitorNetwork = true;
    // logLevel = BugseeLogLevel.verbose;
    maxDataSize = 50;
    reportPrioritySelector = false;
    defaultCrashPriority = BugseeSeverityLevel.blocker;
    defaultBugPriority = BugseeSeverityLevel.high;
    frameRate = BugseeFrameRate.high;
    wifiOnlyUpload = false;
    maxNetworkBodySize = MAX_BODY_LENGTH;
    captureDeviceAndNetworkNames = false;
    viewHierarchyEnabled = true;
    reportSummaryRequired = false;
    reportDescriptionRequired = false;
    reportEmailRequired = false;
    reportLabelsEnabled = false;
    reportLabelsRequired = false;
  }

  /// Adds specified custom launch option
  void setCustomOption(String key, dynamic value) {
    this[key] = value;
  }

  /// Video capturing frame rate
  BugseeFrameRate get frameRate =>
      BugseeFrameRate.values[this["FrameRate"] - 1];
  set frameRate(BugseeFrameRate frameRate) {
    this["FrameRate"] = frameRate.index + 1;
  }

  /// Maximum recording duration
  int get maxRecordingTime => this["MaxRecordingTime"];
  set maxRecordingTime(int value) {
    this["MaxRecordingTime"] = value;
  }

  /// Shake gesture to trigger report
  bool get shakeToReport => this["ShakeToReport"];
  set shakeToReport(bool value) {
    this["ShakeToReport"] = value;
  }

  /// Catch and report application crashes
  bool get crashReport => this["CrashReport"];
  set crashReport(bool value) {
    this["CrashReport"] = value;
  }

  /// Enable video recording
  bool get videoEnabled => this["VideoEnabled"];
  set videoEnabled(bool value) {
    this["VideoEnabled"] = value;
  }

  /// Enable video recording
  double get videoScale => this["VideoScale"];
  set videoScale(double value) {
    this["VideoScale"] = max(value, 0.0);
  }

  /// Automatically capture all console logs
  bool get captureLogs => this["CaptureLogs"];
  set captureLogs(bool value) {
    this["CaptureLogs"] = value;
  }

  /// Capture network traffic
  bool get monitorNetwork => this["MonitorNetwork"];
  set monitorNetwork(bool value) {
    this["MonitorNetwork"] = value;
  }

  /// Allow user to modify priority when reporting manually
  bool get reportPrioritySelector => this["BugseeReportPrioritySelector"];
  set reportPrioritySelector(bool value) {
    this["BugseeReportPrioritySelector"] = value;
  }

  /// Default priority for crashes
  BugseeSeverityLevel get defaultCrashPriority =>
      BugseeSeverityLevel.values[this["BugseeDefaultCrashPriority"] - 1];
  set defaultCrashPriority(BugseeSeverityLevel value) {
    this["BugseeDefaultCrashPriority"] = value.index + 1;
  }

  /// Default priority for bugs
  BugseeSeverityLevel get defaultBugPriority =>
      BugseeSeverityLevel.values[this["BugseeDefaultBugPriority"] - 1];
  set defaultBugPriority(BugseeSeverityLevel value) {
    this["BugseeDefaultBugPriority"] = value.index + 1;
  }

  /// Attach screenshot to a report.
  bool get screenshotEnabled => this["ScreenshotEnabled"];
  set screenshotEnabled(bool value) {
    this["ScreenshotEnabled"] = value;
  }

  /// Enable View hierarchy capturing
  bool get viewHierarchyEnabled => this["ViewHierarchyEnabled"];
  set viewHierarchyEnabled(bool value) {
    this["ViewHierarchyEnabled"] = value;
  }

  /// Upload reports only when a device is connected to a wifi network.
  bool get wifiOnlyUpload => this["WifiOnlyUpload"];
  set wifiOnlyUpload(bool value) {
    this["WifiOnlyUpload"] = value;
  }

  /// Bugsee will avoid using more disk space than specified (in MB). If total Bugsee data size exceeds
  /// specified value, oldest recordings (even not sent) will be removed. Value should not be smaller
  /// than 10.
  int get maxDataSize => this["MaxDataSize"];
  set maxDataSize(int value) {
    this["MaxDataSize"] = value;
  }

  /// The maximal size of network request/response body.
  int get maxNetworkBodySize => this["bodySizeLimit"];
  set maxNetworkBodySize(int value) {
    this["bodySizeLimit"] = value;
  }

  bool get captureDeviceAndNetworkNames => this["CaptureDeviceAndNetworkNames"];
  set captureDeviceAndNetworkNames(bool value) {
    this["CaptureDeviceAndNetworkNames"] = value;
  }

  /// Controls whether Summary field is defined as mandatory in bug reporting UI
  bool get reportSummaryRequired => this["ReportSummaryRequired"];
  set reportSummaryRequired(bool value) {
    this["ReportSummaryRequired"] = value;
  }

  /// Controls whether Description field is defined as mandatory in bug reporting UI
  bool get reportDescriptionRequired => this["ReportDescriptionRequired"];
  set reportDescriptionRequired(bool value) {
    this["ReportDescriptionRequired"] = value;
  }

  /// Controls whether Email field is defined as mandatory in bug reporting UI
  bool get reportEmailRequired => this["ReportEmailRequired"];
  set reportEmailRequired(bool value) {
    this["ReportEmailRequired"] = value;
  }

  /// Controls whether Labels field is enabled in bug reporting UI
  bool get reportLabelsEnabled => this["ReportLabelsEnabled"];
  set reportLabelsEnabled(bool value) {
    this["ReportLabelsEnabled"] = value;
  }

  /// Controls whether Labels field is defined as mandatory in bug reporting UI
  bool get reportLabelsRequired => this["ReportLabelsRequired"];
  set reportLabelsRequired(bool value) {
    this["ReportLabelsRequired"] = value;
  }
}

/// Bugsee launch options for iOS
class IOSLaunchOptions extends BugseeLaunchOptions {
  IOSLaunchOptions() : super() {
    this.setDefaults();
  }

  @override
  void setDefaults() {
    super.setDefaults();

    this.style = BugseeIosVisualStyle.defaultColors;
    this.screenshotToReport = this.videoEnabled;
    this.killDetection = false;
    this.monitorBluetoothStatus = false;
  }

  /// Defines the style which is used in Bugsee reporting UI
  BugseeIosVisualStyle get style =>
      BugseeIosVisualStyle.values[this["BugseeStyle"] - 1];
  set style(BugseeIosVisualStyle value) {
    this["BugseeStyle"] = value.index + 1;
  }

  /// Screenshot key to trigger report
  bool get screenshotToReport => this["ScreenshotToReport"];
  set screenshotToReport(bool value) {
    this["ScreenshotToReport"] = value;
  }

  /// Detect abnormal termination (experimental)
  bool get killDetection => this["BugseeKillDetectionKey"];
  set killDetection(bool value) {
    this["BugseeKillDetectionKey"] = value;
  }

  /// Constantly monitor Bluetooth status
  bool get monitorBluetoothStatus => this["MonitorBluetoothStatus"];
  set monitorBluetoothStatus(bool value) {
    this["MonitorBluetoothStatus"] = value;
  }
}

class AndroidLaunchOptions extends BugseeLaunchOptions {
  AndroidLaunchOptions() : super() {
    this.setDefaults();
  }

  @override
  void setDefaults() {
    super.setDefaults();

    this.serviceMode = false;
    // default is set to V3 to make sure we capture
    // what Flutter is rendering onto the GL surface
    this.videoMode = BugseeVideoMode.v3;
    // this is required as V3 is no allowed on
    // some devices (e.g. Samsung), but is
    // required for Flutter as it renders its
    // UI onto GL surface
    this["forceVideoModeV3"] = true;
  }

  /// Video capture mode
  BugseeVideoMode get videoMode => BugseeVideoMode.values[this["VideoMode"]];
  set videoMode(BugseeVideoMode value) {
    this["VideoMode"] = value.index;
  }

  /// Whether application Bugsee is contained within is running as service
  bool get serviceMode => this["ServiceMode"];
  set serviceMode(bool value) {
    this["ServiceMode"] = value;
  }

  ///
  bool get notificationBarTrigger => this["NotificationBarTrigger"];
  set notificationBarTrigger(bool value) {
    this["NotificationBarTrigger"] = value;
  }
}

BugseeLaunchOptions? getDefaultLaunchOptions() {
  if (Platform.isIOS) {
    return IOSLaunchOptions();
  }

  if (Platform.isAndroid) {
    return AndroidLaunchOptions();
  }

  return null;
}
