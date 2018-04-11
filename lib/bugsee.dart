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
            frame.package == 'flutter')
          user = false;

        if (package == null) {
          if (frame.uri.scheme == 'dart') package = 'dart';
          else package = 'application';
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
