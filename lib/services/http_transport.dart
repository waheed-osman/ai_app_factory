import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/errors.dart';

class HttpResult {
  const HttpResult(this.status, this.headers, this.bodyBytes);

  final int status;

  /// Response headers with lower-case names.
  final Map<String, String> headers;
  final Uint8List bodyBytes;

  bool get ok => status >= 200 && status < 300;

  bool get isRedirect => status >= 300 && status < 400;

  String get text => utf8.decode(bodyBytes, allowMalformed: true);

  dynamic get json => jsonDecode(text);

  String? header(String name) => headers[name.toLowerCase()];
}

/// Abstraction over HTTP so services can be tested without a network.
abstract class HttpTransport {
  Future<HttpResult> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
    bool followRedirects = true,
  });
}

class IoHttpTransport implements HttpTransport {
  IoHttpTransport({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<HttpResult> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
    bool followRedirects = true,
  }) async {
    final request = http.Request(method, url);
    request.followRedirects = followRedirects;
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (jsonBody != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(jsonBody);
    }
    try {
      final streamed =
          await _client.send(request).timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(streamed);
      return HttpResult(
        response.statusCode,
        response.headers,
        response.bodyBytes,
      );
    } on TimeoutException {
      throw FactoryException('انتهت مهلة الاتصال بالخادم.');
    } on http.ClientException catch (error) {
      throw FactoryException(
        'تعذّر الاتصال بالإنترنت.',
        details: error.message,
      );
    }
  }
}

/// Throws a [FactoryException] unless [result] is a 2xx response.
HttpResult ensureOk(HttpResult result, String what) {
  if (result.ok) return result;
  final body = result.text;
  final clipped = body.length > 1500 ? body.substring(0, 1500) : body;
  throw FactoryException(
    'فشل $what (HTTP ${result.status}).',
    details: clipped,
  );
}
