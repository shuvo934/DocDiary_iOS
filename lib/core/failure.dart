enum FailureKind { network, server, invalidData, denied, storage }

/// A discarded read must not display an error or queue later work.
class ObsoleteRequest implements Exception {
  const ObsoleteRequest();
}

class AppFailure implements Exception {
  const AppFailure(this.message, {this.kind = FailureKind.server});
  final String message;
  final FailureKind kind;

  @override
  String toString() => message;
}
