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
