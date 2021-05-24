import 'dart:typed_data';

import 'enums.dart';

typedef BugseeGenericErrorCallback = Future<Null> Function(
    Object error, StackTrace stack);

abstract class BugseeNetworkEvent {
  String get type;
  String get method;
  String url = "";
  String? redirectUrl;
  String? body;
  Map<String, dynamic>? headers;
}

typedef BugseeNetworkFilterCallback = Future<BugseeNetworkEvent?> Function(
    BugseeNetworkEvent e);

class BugseeLogEvent {
  String text;
  BugseeLogLevel level;

  BugseeLogEvent(this.text, this.level);
}

typedef BugseeLogFilterCallback = Future<BugseeLogEvent?> Function(
    BugseeLogEvent e);

typedef BugseeLifecycleCallback = void Function(BugseeLifecycleEventType e);

class BugseeReport {
  final String type;
  final BugseeSeverityLevel severity;

  BugseeReport(this.type, this.severity);
}

class BugseeAttachment {
  final String name;
  final String filename;
  final Uint8List data;

  BugseeAttachment(this.name, this.filename, this.data);
}

typedef BugseeAttachmentsCallback = Future<List<BugseeAttachment>?> Function(
    BugseeReport report);

typedef BugseeNewFeedbackMessagesCallback = void Function(
    List<String> messages);
