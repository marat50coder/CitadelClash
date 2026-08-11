import 'package:http/http.dart' as http;

import 'ua_builder.dart';

// ============================================================
// TAGGED CLIENT — http client that always carries the device UA
// ============================================================
// Every outbound conduit request (config POST, GCD rescue, push image
// fetch) flows through here so nothing leaks the default `dart-io`
// agent string.
// ============================================================

class TaggedClient extends http.BaseClient {
  TaggedClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = UaBuilder.value;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

final TaggedClient taggedClient = TaggedClient();
