/// Author: Zakaria Hossain
/// Description: Defines phonetic exception classes and error hierarchies.
library;

/// Base type of every problem the package reports.
///
/// Errors are returned in result records, not thrown.
sealed class PhoneticException implements Exception {
  const PhoneticException(this.message);

  /// A short description of what went wrong.
  final String message;
}

/// The request was cancelled before it finished.
final class PhoneticCancelledException extends PhoneticException {
  const PhoneticCancelledException(
      [super.message = 'The phonetics request was cancelled']);

  @override
  String toString() => 'PhoneticCancelledException: $message';
}

/// An argument, rule or language definition was not valid.
final class PhoneticArgumentException extends PhoneticException {
  const PhoneticArgumentException(super.message);

  @override
  String toString() => 'PhoneticArgumentException: $message';
}

/// The instance was disposed and cannot run requests.
final class PhoneticDisposedException extends PhoneticException {
  const PhoneticDisposedException([super.message = 'Phonetics was disposed']);

  @override
  String toString() => 'PhoneticDisposedException: $message';
}

/// The background worker failed or is not available.
final class PhoneticWorkerException extends PhoneticException {
  const PhoneticWorkerException(super.message);

  @override
  String toString() => 'PhoneticWorkerException: $message';
}
