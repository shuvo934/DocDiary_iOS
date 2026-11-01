import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../core/failure.dart';

abstract interface class ReportPdfTransport {
  Future<Uint8List> get(Uri uri, {required bool Function() isCurrent});
  void close();
}

/// Binary Oracle GET; no automatic retries, redirects or URL/response logging.
class IoReportPdfTransport implements ReportPdfTransport {
  IoReportPdfTransport({
    HttpClient? client,
    this.timeout = const Duration(seconds: 50),
  }) : _client = client ?? HttpClient() {
    _client.connectionTimeout = timeout;
  }
  final HttpClient _client;
  final Duration timeout;
  static const maxBytes = 24 * 1024 * 1024;
  bool _closed = false;
  @override
  Future<Uint8List> get(Uri uri, {required bool Function() isCurrent}) async {
    void guard() {
      if (_closed || !isCurrent()) throw const ObsoleteRequest();
    }

    guard();
    if (!const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const AppFailure(
        'The report server address is invalid.',
        kind: FailureKind.invalidData,
      );
    }
    HttpClientRequest? request;
    var expired = false;
    try {
      return await (() async {
        final outgoing = await _client.getUrl(uri);
        request = outgoing;
        if (expired) {
          outgoing.abort();
          throw const ObsoleteRequest();
        }
        guard();
        outgoing.followRedirects = false;
        outgoing.headers.set(HttpHeaders.acceptHeader, 'application/pdf');
        final response = await outgoing.close();
        guard();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          outgoing.abort();
          throw const AppFailure(
            'Could not download the report PDF. Please try again.',
          );
        }
        if (response.contentLength > maxBytes) {
          outgoing.abort();
          throw const AppFailure(
            'The report PDF is too large to open. Please choose a shorter date range.',
          );
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response) {
          guard();
          if (bytes.length + chunk.length > maxBytes) {
            outgoing.abort();
            throw const AppFailure(
              'The report PDF is too large to open. Please choose a shorter date range.',
            );
          }
          bytes.add(chunk);
        }
        guard();
        final result = bytes.takeBytes();
        validateReportPdf(result);
        return result;
      })().timeout(
        timeout,
        onTimeout: () {
          expired = true;
          request?.abort();
          throw const AppFailure(
            'The report download timed out. Please try again.',
            kind: FailureKind.network,
          );
        },
      );
    } on ObsoleteRequest {
      rethrow;
    } on AppFailure {
      rethrow;
    } catch (_) {
      guard();
      throw const AppFailure(
        'Could not download the report PDF. Please check your connection and try again.',
        kind: FailureKind.network,
      );
    }
  }

  @override
  void close() {
    _closed = true;
    _client.close(force: true);
  }
}

void validateReportPdf(Uint8List data) {
  const magic = [37, 80, 68, 70, 45];
  if (data.length < 5 ||
      data.length > IoReportPdfTransport.maxBytes ||
      !List.generate(5, (i) => data[i] == magic[i]).every((v) => v)) {
    throw const AppFailure(
      'The report server did not return a valid PDF. Please try again.',
      kind: FailureKind.invalidData,
    );
  }
}
