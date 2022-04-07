import 'dart:math';

import 'package:flutter/material.dart';

import 'types.dart';

class BugseeNetworkEventImpl extends BugseeNetworkEvent {
  String _internalMethod = '';
  String _internalEventType = "";
  String get method => _internalMethod;
  String get type => _internalEventType;

  /// Convert raw event data received from the native layer
  /// into the class instance with proper fields
  static BugseeNetworkEvent? fromRawEvent(dynamic? event) {
    if (event == null) {
      return null;
    }

    BugseeNetworkEventImpl wrappedEvent = BugseeNetworkEventImpl();
    wrappedEvent._internalMethod = event['method'];
    wrappedEvent._internalEventType = event['type'];
    wrappedEvent.url = event['url'];
    wrappedEvent.body = event['body'];
    wrappedEvent.redirectUrl = event['redirectUrl'];
    wrappedEvent.headers = event['headers'];

    return wrappedEvent;
  }

  /// Convert class instance denoting the network event into
  /// the raw event data to pass it back to the native layer
  static dynamic augmentAndExtendOriginalEvent(
      dynamic originalEvent, BugseeNetworkEvent? e) {
    if (e == null) {
      return null;
    }

    originalEvent['url'] = e.url;
    originalEvent['body'] = e.body;
    originalEvent['redirectUrl'] = e.redirectUrl;
    originalEvent['headers'] = e.headers;

    return originalEvent;
  }
}

typedef BugseeAdditionalDataCaptureCallback = String? Function(String kind);

class ViewHierarchyItem {
  String id = "";
  Rectangle bounds = Rectangle(0, 0, 0, 0);
  String className = "";
  String? baseClassName;
  Map<String, dynamic>? options;
  List<ViewHierarchyItem>? subitems;

  ViewHierarchyItem(String id, Rectangle bounds, String className) {
    this.id = id;
    this.bounds = bounds;
    this.className = className;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      "id": id,
      "bounds": [bounds.left, bounds.top, bounds.width, bounds.height],
      "class_name": className
    };
    if (baseClassName != null) {
      map["base_class_name"] = baseClassName;
    }
    if (options != null) {
      map["options"] = options;
    }
    if (subitems != null) {
      map["subitems"] = subitems!.map((item) => item.toMap()).toList();
    }
    return map;
  }
}
