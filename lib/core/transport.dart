import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'failure.dart';
import 'native_json.dart';

abstract interface class Transport {
  Future<String> getText(Uri uri);
  Future<JsonMap> get(Uri uri);
  Future<JsonMap> post(Uri uri, {Map<String, String> headers = const {}});
  void close();
}

/// iOS-only transport. There is deliberately no automatic POST retry and no
/// request/response logging: legacy login sends credentials in the query.
class IoTransport implements Transport {
  IoTransport({this.timeout = const Duration(seconds: 25), HttpClient? client})
    : _client = client ?? HttpClient() {
    _client.connectionTimeout = timeout;
  }

  final HttpClient _client;
  final Duration timeout;
  static const _maxBytes = 8 * 1024 * 1024;

  @override
  Future<String> getText(Uri uri) => _request('GET', uri);

  @override
  Future<JsonMap> get(Uri uri) async => nativeObject(await getText(uri));

  @override
  Future<JsonMap> post(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async => nativeObject(await _request('POST', uri, headers: headers));

  Future<String> _request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    HttpClientRequest? request;
    var expired = false;
    try {
      return await (() async {
        final outgoing = await _client.openUrl(method, uri);
        request = outgoing;
        if (expired) {
          outgoing.abort();
          throw const AppFailure(
            'The request timed out.',
            kind: FailureKind.network,
          );
        }
        // Never forward login queries or custom identity headers to a redirect.
        outgoing.followRedirects = false;
        outgoing.headers.set(
          HttpHeaders.acceptHeader,
          'application/json, text/plain',
        );
        headers.forEach((key, value) {
          if (value.contains('\r') || value.contains('\n')) {
            throw const AppFailure(
              'An account value contains invalid characters.',
              kind: FailureKind.invalidData,
            );
          }
          outgoing.headers.set(key, value, preserveHeaderCase: true);
        });
        final response = await outgoing.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>();
          throw AppFailure(
            'The server could not complete the request (HTTP ${response.statusCode}).',
          );
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > _maxBytes) {
            throw const AppFailure(
              'The server response is too large.',
              kind: FailureKind.invalidData,
            );
          }
          bytes.addAll(chunk);
        }
        return utf8.decode(bytes);
      })().timeout(timeout);
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      expired = true;
      request?.abort();
      throw const AppFailure(
        'The server took too long to respond. Please try again.',
        kind: FailureKind.network,
      );
    } on SocketException {
      throw const AppFailure(
        'Server Problem or Internet Not Connected',
        kind: FailureKind.network,
      );
    } on HandshakeException {
      throw const AppFailure(
        'A secure connection to the server could not be made.',
        kind: FailureKind.network,
      );
    } on HttpException {
      throw const AppFailure(
        'The connection was interrupted. Please try again.',
        kind: FailureKind.network,
      );
    } on FormatException {
      throw const AppFailure(
        'The server returned unreadable data.',
        kind: FailureKind.invalidData,
      );
    } catch (_) {
      throw const AppFailure(
        'The request could not be completed. Please try again.',
      );
    }
  }

  @override
  void close() => _client.close(force: true);
}
