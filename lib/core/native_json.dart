import 'dart:convert';

import 'failure.dart';

typedef JsonMap = Map<String, Object?>;

String nativeText(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  final result = value.toString();
  return result.trim().isEmpty || result.trim().toLowerCase() == 'null'
      ? fallback
      : result;
}

JsonMap nativeObject(Object? value) {
  try {
    final Object? decoded = value is String ? jsonDecode(value) : value;
    if (decoded is Map<String, Object?>) return Map.of(decoded);
  } on FormatException {
    // Present a bounded message rather than leaking a raw response.
  }
  throw const AppFailure(
    'The server returned an unexpected response.',
    kind: FailureKind.invalidData,
  );
}

List<JsonMap> nativeArray(Object? value) {
  if (value == null || value == '' || value == 'null') return [];
  try {
    final Object? decoded = value is String ? jsonDecode(value) : value;
    if (decoded is List<Object?>) {
      return decoded.map(nativeObject).toList(growable: false);
    }
  } on FormatException {
    // ORDS can return an array as either JSON or an encoded JSON string.
  }
  throw const AppFailure(
    'The server returned an unexpected list.',
    kind: FailureKind.invalidData,
  );
}

List<JsonMap> nativeItems(JsonMap response) => nativeArray(response['items']);

Uri apiBase(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const AppFailure(
      'The centre server address is invalid.',
      kind: FailureKind.invalidData,
    );
  }
  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}

Uri apiEndpoint(Uri base, String path, [Map<String, String>? query]) =>
    base.resolve(path).replace(queryParameters: query);
