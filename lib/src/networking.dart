import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:bugsee/src/state.dart';
import 'package:uuid/uuid.dart';

import '../bugsee.dart';

const Uuid _globalUuid = const Uuid();

void _registerBeginEvent(_BugseeHttpClientRequest request,
    [String? noBodyReason, String? body, int? timestamp]) {
  dynamic eventData = <String, dynamic>{
    'id': request.requestID,
    'timestamp': timestamp ?? request.timestamp,
    'url': request.uri.toString(),
    'method': request.method,
    'type': 'before',
    'size': request.contentLength,
    'body': body
  };

  eventData['isSupplement'] = (noBodyReason != null) || (body != null);

  if (noBodyReason != null) {
    eventData['noBodyReason'] = noBodyReason;
  } else if (body != null) {
    eventData['body'] = body;
  }

  dynamic headers = <String, dynamic>{};
  request.headers.forEach((name, values) {
    headers[name] = values.join(', ');
  });

  eventData['headers'] = headers;

  Bugsee.registerNetworkEvent(eventData);
}

void _registerCompleteEvent(_BugseeHttpClientResponse response,
    [String? noBodyReason, String? body, int? timestamp]) {
  var isError = response.statusCode >= 400;
  dynamic eventData = <String, dynamic>{
    'id': response.requestID,
    'timestamp': timestamp ?? response.timestamp,
    'url': response.originalUrl,
    'type': isError ? 'error' : 'complete',
    'size': body?.length ?? response.contentLength,
    'status': response.statusCode
  };

  eventData['isSupplement'] = noBodyReason != null || body != null;

  if (noBodyReason != null) {
    eventData['noBodyReason'] = noBodyReason;
  } else if (body != null) {
    eventData['body'] = body;
  }

  if (isError) {
    eventData['error'] = response.reasonPhrase;
  }

  if (response.isRedirect) {
    // TODO: register all the intermediate redirects too
    eventData['redirectUrl'] = response.redirects.last.location.toString();
  }

  dynamic headers = <String, dynamic>{};
  response.headers.forEach((name, values) {
    headers[name] = values.join(', ');
  });

  eventData['headers'] = headers;

  Bugsee.registerNetworkEvent(eventData);
}

Future<_BugseeHttpClientRequest> _wrapRequest(
    Future<HttpClientRequest> request) async {
  var timestamp = DateTime.now().microsecondsSinceEpoch;

  return request.then((actualRequest) {
    if (actualRequest is _BugseeHttpClientRequest) {
      return request as Future<_BugseeHttpClientRequest>;
    }

    return Future.value(_BugseeHttpClientRequest(actualRequest, timestamp));
  });
}

_BugseeHttpClientResponse _wrapResponse(HttpClientResponse response,
    String requestID, String originalUrl, int timestamp) {
  if (response is _BugseeHttpClientResponse) {
    return response;
  }

  return _BugseeHttpClientResponse(response, requestID, originalUrl, timestamp);
}

void _readRequestBody(_BugseeHttpClientRequest request) {
  String? noBodyReason;
  String? body;
  var options = getLaunchOptions()!;

  if (request.contentLength > options.maxNetworkBodySize) {
    noBodyReason = 'size_too_large';
  } else if (request.headers.contentType == null) {
    noBodyReason = 'no_content_type';
  } else if (request.headers.contentType == ContentType.binary) {
    noBodyReason = 'unsupported_content_type';
  } else if (request._sendBuffer == null) {
    noBodyReason = 'cant_read_data';
  } else if (request._sendBuffer != null &&
      request._sendBuffer!.length > options.maxNetworkBodySize) {
    noBodyReason = 'size_too_large';
  }

  if (noBodyReason == null) {
    try {
      body = request._sendBuffer.toString();
    } catch (ex) {
      noBodyReason = 'cant_read_data';
    }
  }

  _registerBeginEvent(request, noBodyReason, body, request.timestamp);
}

void _readResponseBody(_BugseeHttpClientResponse response) {
  String? noBodyReason;
  String? body;
  var options = getLaunchOptions()!;

  if (response.contentLength > options.maxNetworkBodySize) {
    noBodyReason = 'size_too_large';
  } else if (response.headers.contentType == null) {
    noBodyReason = 'no_content_type';
  } else if (response.headers.contentType == ContentType.binary) {
    noBodyReason = 'unsupported_content_type';
  } else if (response._receiveBuffer == null) {
    noBodyReason = 'cant_read_data';
  } else if (response._receiveBuffer != null &&
      response._receiveBuffer!.length > options.maxNetworkBodySize) {
    noBodyReason = 'size_too_large';
  }

  if (noBodyReason == null) {
    try {
      body = response._receiveBuffer?.toString();
    } catch (ex) {
      noBodyReason = 'cant_read_data';
    }
  }

  _registerCompleteEvent(response, noBodyReason, body);
}

class BugseeHttpClient implements HttpClient {
  final HttpClient _httpClient;

  BugseeHttpClient([HttpClient? httpClient, SecurityContext? context])
      : _httpClient = httpClient ?? HttpClient(context: context);

  @override
  bool get autoUncompress => _httpClient.autoUncompress;
  set autoUncompress(bool value) {
    _httpClient.autoUncompress = value;
  }

  @override
  Duration? get connectionTimeout => _httpClient.connectionTimeout;
  set connectionTimeout(Duration? value) {
    _httpClient.connectionTimeout = value;
  }

  @override
  Duration get idleTimeout => _httpClient.idleTimeout;
  set idleTimeout(Duration value) {
    _httpClient.idleTimeout = value;
  }

  @override
  int? get maxConnectionsPerHost => _httpClient.maxConnectionsPerHost;
  set maxConnectionsPerHost(int? value) {
    _httpClient.maxConnectionsPerHost = value;
  }

  @override
  String? get userAgent => _httpClient.userAgent;
  set userAgent(String? value) {
    _httpClient.userAgent = value;
  }

  @override
  void addCredentials(
      Uri url, String realm, HttpClientCredentials credentials) {
    _httpClient.addCredentials(url, realm, credentials);
  }

  @override
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials credentials) {
    _httpClient.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set authenticate(
      Future<bool> Function(Uri url, String scheme, String realm)? f) {
    _httpClient.authenticate = f;
  }

  @override
  set authenticateProxy(
      Future<bool> Function(String host, int port, String scheme, String realm)?
          f) {
    _httpClient.authenticateProxy = f;
  }

  @override
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port)? callback) {
    _httpClient.badCertificateCallback = callback;
  }

  @override
  void close({bool force = false}) {
    _httpClient.close(force: force);
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    return _wrapRequest(_httpClient.delete(host, port, path));
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    return _wrapRequest(_httpClient.deleteUrl(url));
  }

  @override
  set findProxy(String Function(Uri url)? f) {
    _httpClient.findProxy = f;
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    return _wrapRequest(_httpClient.get(host, port, path));
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    return _wrapRequest(_httpClient.getUrl(url));
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    return _wrapRequest(_httpClient.head(host, port, path));
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) async {
    return _wrapRequest(_httpClient.headUrl(url));
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    return _wrapRequest(_httpClient.open(method, host, port, path));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    return _wrapRequest(_httpClient.openUrl(method, url));
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    return _wrapRequest(_httpClient.patch(host, port, path));
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    return _wrapRequest(_httpClient.patchUrl(url));
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    return _wrapRequest(_httpClient.post(host, port, path));
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _wrapRequest(_httpClient.postUrl(url));
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    return _wrapRequest(_httpClient.put(host, port, path));
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    return _wrapRequest(_httpClient.putUrl(url));
  }
}

class _BugseeHttpClientRequest extends HttpClientRequest {
  final String requestID;
  final int timestamp;
  final HttpClientRequest _httpClientRequest;
  StringBuffer? _sendBuffer = StringBuffer();

  _BugseeHttpClientRequest(this._httpClientRequest, [int? eventTimestamp])
      : requestID = _globalUuid.v4(),
        timestamp = eventTimestamp ?? DateTime.now().microsecondsSinceEpoch {
    // subscribe for the completion event right away so we will be notified
    // when request completes
    var request = this;

    _registerBeginEvent(request);

    request.done.then((value) {
      _readRequestBody(request);

      var response = _wrapResponse(
          value, requestID, request.uri.toString(), this.timestamp);
      _registerCompleteEvent(
          response, null, null, DateTime.now().millisecondsSinceEpoch);
      return response;
    }, onError: (dynamic err) {
      // print(err);
      // _registerErrorEvent()
    });
  }

  void _checkAndResetBufferIfRequired() {
    if (_sendBuffer != null &&
        _sendBuffer!.length > getLaunchOptions()!.maxNetworkBodySize) {
      // we have collected too many bytes -> reset buffer
      _sendBuffer = null;
    }
  }

  void _addItems(List<int> data) {
    if (this.headers.contentType != ContentType.binary) {
      try {
        _sendBuffer?.write(utf8.decode(data));
      } catch (ex) {}
      _checkAndResetBufferIfRequired();
    }
  }

  Stream<List<int>> _readAndRecreateStream(Stream<List<int>> source) async* {
    await for (var chunk in source) {
      _addItems(chunk);
      yield chunk;
    }
  }

  @override
  Encoding get encoding => _httpClientRequest.encoding;
  set encoding(Encoding value) {
    _httpClientRequest.encoding = value;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _httpClientRequest.abort(exception, stackTrace);
  }

  @override
  void add(List<int> data) {
    _addItems(data);
    _httpClientRequest.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _httpClientRequest.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    var newStream = _readAndRecreateStream(stream);
    return _httpClientRequest.addStream(newStream);
  }

  @override
  Future<HttpClientResponse> close() {
    return _httpClientRequest.close().then((response) => _wrapResponse(response,
        requestID, _httpClientRequest.uri.toString(), this.timestamp));
  }

  @override
  HttpConnectionInfo? get connectionInfo => _httpClientRequest.connectionInfo;

  @override
  List<Cookie> get cookies => _httpClientRequest.cookies;

  @override
  Future<HttpClientResponse> get done {
    return _httpClientRequest.done.then((response) => _wrapResponse(response,
        requestID, _httpClientRequest.uri.toString(), this.timestamp));
  }

  @override
  Future flush() {
    return _httpClientRequest.flush();
  }

  @override
  HttpHeaders get headers => _httpClientRequest.headers;

  @override
  String get method => _httpClientRequest.method;

  @override
  Uri get uri => _httpClientRequest.uri;

  @override
  void write(Object? object) {
    _httpClientRequest.write(object);
    if (headers.contentType != ContentType.binary) {
      try {
        _sendBuffer?.write(object);
      } catch (ex) {}
      _checkAndResetBufferIfRequired();
    }
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    _httpClientRequest.writeAll(objects);
    if (headers.contentType != ContentType.binary) {
      try {
        _sendBuffer?.writeAll(objects, separator);
      } catch (ex) {}
      _checkAndResetBufferIfRequired();
    }
  }

  @override
  void writeCharCode(int charCode) {
    _httpClientRequest.writeCharCode(charCode);
    if (headers.contentType != ContentType.binary) {
      try {
        _sendBuffer?.writeCharCode(charCode);
      } catch (ex) {}
      _checkAndResetBufferIfRequired();
    }
  }

  @override
  void writeln([Object? object = ""]) {
    _httpClientRequest.writeln(object);
    if (headers.contentType != ContentType.binary) {
      try {
        _sendBuffer?.writeln(object);
      } catch (ex) {}
      _checkAndResetBufferIfRequired();
    }
  }
}

class _BugseeHttpClientResponse extends HttpClientResponse {
  final HttpClientResponse _httpClientResponse;
  final String requestID;
  final String originalUrl;
  final int timestamp;
  Stream<List<int>>? _wrapperStream;
  StringBuffer? _receiveBuffer = StringBuffer();

  _BugseeHttpClientResponse(this._httpClientResponse, this.requestID,
      this.originalUrl, this.timestamp) {
    _wrapperStream = _readAndRecreateStream(_httpClientResponse);
  }

  void _checkAndResetBufferIfRequired() {
    if (_receiveBuffer != null &&
        _receiveBuffer!.length > getLaunchOptions()!.maxNetworkBodySize) {
      // we have collected too many bytes -> reset buffer
      _receiveBuffer = null;
    }
  }

  void _addItems(List<int> data) {
    if (this.headers.contentType != ContentType.binary) {
      try {
        _receiveBuffer?.write(utf8.decode(data));
      } catch (ex) {}
      _checkAndResetBufferIfRequired();
    }
  }

  Stream<List<int>> _readAndRecreateStream(Stream<List<int>> source) async* {
    await for (var chunk in source) {
      _addItems(chunk);
      yield chunk;
    }

    _readResponseBody(this);
  }

  @override
  Future<bool> any(bool Function(List<int> element) test) {
    return this._wrapperStream!.any(test);
  }

  @override
  Stream<List<int>> asBroadcastStream(
      {void Function(StreamSubscription<List<int>> subscription)? onListen,
      void Function(StreamSubscription<List<int>> subscription)? onCancel}) {
    return this
        ._wrapperStream!
        .asBroadcastStream(onListen: onListen, onCancel: onCancel);
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(List<int> event) convert) {
    return this._wrapperStream!.asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(List<int> event) convert) {
    return this._wrapperStream!.asyncMap(convert);
  }

  @override
  Stream<R> cast<R>() {
    return this._wrapperStream!.cast();
  }

  @override
  X509Certificate? get certificate => this._httpClientResponse.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      this._httpClientResponse.compressionState;

  @override
  HttpConnectionInfo? get connectionInfo =>
      this._httpClientResponse.connectionInfo;

  @override
  Future<bool> contains(Object? needle) {
    return this._wrapperStream!.contains(needle);
  }

  @override
  int get contentLength => this._httpClientResponse.contentLength;

  @override
  List<Cookie> get cookies => this._httpClientResponse.cookies;

  @override
  Future<Socket> detachSocket() {
    return this._httpClientResponse.detachSocket();
  }

  @override
  Stream<List<int>> distinct(
      [bool Function(List<int> previous, List<int> next)? equals]) {
    return this._wrapperStream!.distinct(equals);
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    return this._wrapperStream!.drain(futureValue);
  }

  @override
  Future<List<int>> elementAt(int index) {
    return this._wrapperStream!.elementAt(index);
  }

  @override
  Future<bool> every(bool Function(List<int> element) test) {
    return this._wrapperStream!.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int> element) convert) {
    return this._wrapperStream!.expand(convert);
  }

  @override
  Future<List<int>> get first => this._wrapperStream!.first;

  @override
  Future<List<int>> firstWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    return this._wrapperStream!.firstWhere(test, orElse: orElse);
  }

  @override
  Future<S> fold<S>(
      S initialValue, S Function(S previous, List<int> element) combine) {
    return this._wrapperStream!.fold(initialValue, combine);
  }

  @override
  Future forEach(void Function(List<int> element) action) {
    return this._wrapperStream!.forEach(action);
  }

  @override
  Stream<List<int>> handleError(Function onError, {bool test(error)?}) {
    return this._wrapperStream!.handleError(onError, test: test);
  }

  @override
  HttpHeaders get headers => this._httpClientResponse.headers;

  @override
  bool get isBroadcast => this._wrapperStream!.isBroadcast;

  @override
  Future<bool> get isEmpty => this._wrapperStream!.isEmpty;

  @override
  bool get isRedirect => this._httpClientResponse.isRedirect;

  @override
  Future<String> join([String separator = ""]) {
    return this._wrapperStream!.join(separator);
  }

  @override
  Future<List<int>> get last => this._wrapperStream!.last;

  @override
  Future<List<int>> lastWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    return this._wrapperStream!.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => this._wrapperStream!.length;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return this
        ._wrapperStream!
        .listen(onData, onError: onError, onDone: onDone);
  }

  @override
  Stream<S> map<S>(S Function(List<int> event) convert) {
    return this._wrapperStream!.map(convert);
  }

  @override
  bool get persistentConnection =>
      this._httpClientResponse.persistentConnection;

  @override
  Future pipe(StreamConsumer<List<int>> streamConsumer) {
    return this._wrapperStream!.pipe(streamConsumer);
  }

  @override
  String get reasonPhrase => this._httpClientResponse.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect(
      [String? method, Uri? url, bool? followLoops]) async {
    return this
        ._httpClientResponse
        .redirect(method, url, followLoops)
        .then((response) {
      return _wrapResponse(response, requestID, originalUrl, this.timestamp);
    });
  }

  @override
  List<RedirectInfo> get redirects => this._httpClientResponse.redirects;

  @override
  Future<List<int>> reduce(
      List<int> Function(List<int> previous, List<int> element) combine) {
    return this._wrapperStream!.reduce(combine);
  }

  @override
  Future<List<int>> get single => this._wrapperStream!.single;

  @override
  Future<List<int>> singleWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    return this._wrapperStream!.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<List<int>> skip(int count) {
    return this._wrapperStream!.skip(count);
  }

  @override
  Stream<List<int>> skipWhile(bool Function(List<int> element) test) {
    return this._wrapperStream!.skipWhile(test);
  }

  @override
  int get statusCode => this._httpClientResponse.statusCode;

  @override
  Stream<List<int>> take(int count) {
    return this._wrapperStream!.take(count);
  }

  @override
  Stream<List<int>> takeWhile(bool Function(List<int> element) test) {
    return this._wrapperStream!.takeWhile(test);
  }

  @override
  Stream<List<int>> timeout(Duration timeLimit,
      {void Function(EventSink<List<int>> sink)? onTimeout}) {
    return this._wrapperStream!.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<List<int>>> toList() {
    return this._wrapperStream!.toList();
  }

  @override
  Future<Set<List<int>>> toSet() {
    return this._wrapperStream!.toSet();
  }

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    return this._wrapperStream!.transform(streamTransformer);
  }

  @override
  Stream<List<int>> where(bool Function(List<int> event) test) {
    return this._wrapperStream!.where(test);
  }
}

class BugseeHttpOverrides extends HttpOverrides {
  HttpOverrides? _wrappedOverrides;

  BugseeHttpOverrides([HttpOverrides? wrappedOverrides]) : super() {
    _wrappedOverrides = wrappedOverrides;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    if (_wrappedOverrides != null) {
      return _wrappedOverrides!.createHttpClient(context);
    }

    // super call is crucial here -> it actually creates the instance of
    // the built-in HttpClient IMPL
    // https://github.com/flutter/flutter/issues/19588#issuecomment-406771070
    return BugseeHttpClient(super.createHttpClient(context));
  }
}
