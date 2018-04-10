import 'dart:async';

import 'dart:convert';
import 'package:meta/meta.dart';
import 'package:flutter/services.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:crypto/crypto.dart';
import 'package:crypto/src/digest_sink.dart';

class Bugsee {
  static const MethodChannel _channel =
      const MethodChannel('bugsee');

  static Future<Null> event({@required String name, Map<String, dynamic> parameters}) async {
    await _channel.invokeMethod('event', <String, dynamic>{
      'name': name,
      'parameters': parameters,
    });
  }

  static Future<Null> trace({@required String name, @required dynamic value}) async {
    await _channel.invokeMethod('trace', <String, dynamic>{
      'name': name,
      'value': value,
    });
  }

  static Future<Null> setAttribute({@required String key, @required dynamic value}) async {
    await _channel.invokeMethod('setAttribute', <String, dynamic>{
      'key': key,
      'value': value,
    });
  }

  static Future<Null> clearAttribute({@required String key}) async {
    await _channel.invokeMethod('clearAttribute', <String, dynamic>{
      'key': key,
    });
  }

  static Future<Null> logException({@required dynamic exception, @required bool handled, dynamic stackTrace}) async {
    final Chain chain = stackTrace is StackTrace
      ? new Chain.forTrace(stackTrace)
      : new Chain.parse(stackTrace);

    final List<dynamic> traces = <dynamic>[];
	var ds = new DigestSink();
	var s = sha1.startChunkedConversion(ds);
  	for (int t = 0; t < chain.traces.length; t += 1) {

    	final List<Map<String, dynamic>> frames = <Map<String, dynamic>>[];
    	for (int f = 0; f < chain.traces[t].frames.length; f += 1) {
    		frames.add(<String, dynamic>{
			  'uri': '${chain.traces[t].frames[f].uri}',
			  'member': chain.traces[t].frames[f].member,
			  'line': chain.traces[t].frames[f].line,
			  'isCore': chain.traces[t].frames[f].isCore,
			});

			s.add(UTF8.encode('${chain.traces[t].frames[f].uri}'));
    	}

    	traces.add(frames);
  	}
  	s.close();

    final dynamic ex = <String, dynamic>{
      'name': '${exception.runtimeType}',
      'reason': '$exception',
      'traces': traces,
      'signature': '${ds.value}',
    };

    await _channel.invokeMethod('logException', <String, dynamic>{
      'name': 'FlutterManagedException',
      'reason': '$ex',
      'handled': handled,
      'signature': '${ds.value}',
    });
  }
}
