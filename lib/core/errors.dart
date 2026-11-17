/// Error with a message that is safe to show to the user.
class FactoryException implements Exception {
  FactoryException(this.message, {this.details = ''});

  final String message;

  /// Extra technical text (server reply, build log) shown on demand.
  final String details;

  @override
  String toString() => message;
}

/// Raised when the remote CI build finishes without producing an APK.
class BuildFailedException extends FactoryException {
  BuildFailedException(super.message, {super.details});
}
