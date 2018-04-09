import 'dart:async';

import 'package:flutter/services.dart';

class Bugsee {
  static const MethodChannel _channel =
      const MethodChannel('bugsee');

  static Future<String> get platformVersion =>
      _channel.invokeMethod('getPlatformVersion');
}
