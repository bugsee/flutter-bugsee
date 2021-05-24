/// Bugsee log level
enum BugseeLogLevel {
  /// Invalid logging level
  invalid,

  /// Error
  error,

  /// Warning
  warning,

  /// Informational message (default)
  info,

  /// Debug message
  debug,

  /// Verboase
  verbose
}

/// Bugsee issue severity level
enum BugseeSeverityLevel {
  /// Low
  low,

  /// Medium
  medium,

  /// High
  high,

  /// Critical
  critical,

  /// Blocker
  blocker
}

/// Bugsee frame rate.
enum BugseeFrameRate {
  /// Low frame rate
  low,

  /// Medium frame rate
  medium,

  /// High frame rate
  high
}

/// Type of issue
enum BugseeIssueType {
  /// Issue is a bug
  bug,

  /// Issue is error
  error,

  /// Issue is crash
  crash
}

// Type of network event
enum BugseeNetworkEventStage {
  /// Event fired before request is being made (start of the request)
  before,

  /// Request is completed
  complete,

  /// Request was cancelled
  cancel,

  /// Request completed with error (or failed without being sent)
  error
}

// enum BugseeNetworkEventTransport { http, webSocket, udpSocket }

/// Bugsee network event no body reason.
enum BugseeNetworkEventNoBodyReason {
  /// No reason. Body must be available.
  none,

  /// Body size is too large to be captured
  sizeTooLarge,

  /// Request conten type is not supported
  unsupportedContentType,

  /// Request/Reponse was not bundled with content type information
  noContentType,

  /// Body can't be read
  cantReadData
}

/// Visual style options for UI on iOS
enum BugseeIosVisualStyle {
  /// Use default color scheme
  defaultColors,

  /// Use fark color scheme
  dark,

  /// Color scheme is based on status bar
  basedOnStatusBar
}

enum BugseeLifecycleEventType {
  /// Event is dispatched when Bugsee was successfully launched
  launched,

  /// Event is dispatched when Bugsee is started after being stopped
  started,

  /// Event is dispatched when Bugsee is stopped
  stopped,

  /// Event is dispatched when Bugsee recording is resumed after being paused
  resumed,

  /// Event is dispatched when Bugsee recording is paused
  paused,

  /// Event is dispatched when Bugsee is launched and pending crash report is
  /// discovered. That usually means that app was relaunched after crash.
  relaunchedAfterCrash,

  /// Event is dispatched before the reporting UI is shown
  beforeReportShown,

  /// Event is dispatched when reporting UI is shown
  afterReportShown,

  /// Event is dispatched when report is about to be uploaded to the server
  beforeReportUploaded,

  /// Event is dispatched when report was successfully uploaded to the server
  afterReportUploaded,

  /// Event is dispatched before the Feedback controller is shown
  beforeFeedbackShown,

  /// Event is dispatched after the Feedback controller is shown
  afterFeedbackShown,

  /// Event is dispatched right before bug/error/crash report is about to be assembled
  beforeReportAssembled,

  /// Event is dispatched right after bug/error/crash report is assembled
  afterReportAssembled
}

/// Video capture modes for Android devices
enum BugseeVideoMode {
  /// Video is not recorded. Created issues will contain console logs, events and traces, but will not contain video.
  none,

  /// User is not asked to allow video recording, but frame rate is lower comparing to {@link VideoMode#V2} mode and some special views
  /// like status bar, soft keyboard and views, which contain Surface (MapView, VideoView, GlSurfaceView, etc.) are not recorded.
  v1,

  /// All types of views are recorded, but user is asked to allow video recording.
  v2,

  /// User is not asked to allow video recording, but frame rate is lower comparing to {@link VideoMode#V2} and system views like status bar
  /// and soft keyboard are not recorded. This mode works only on Android API level 24 and higher. On lower API levels video mode is
  /// automatically switched to {@link VideoMode#V1}.
  v3
}
