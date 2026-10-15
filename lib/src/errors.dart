/// Author: Zakaria Hossain
/// Description: Defines phonetic exception classes and error hierarchies.
library;

sealed class PhoneticException implements Exception {
  const PhoneticException(this.message);

  final String message;
}

final class PhoneticCancelledException extends PhoneticException {
  const PhoneticCancelledException(
      [super.message = 'The phonetics request was cancelled']);

  @override
  String toString() => 'PhoneticCancelledException: $message';
}

final class PhoneticArgumentException extends PhoneticException {
  const PhoneticArgumentException(super.message);

  @override
  String toString() => 'PhoneticArgumentException: $message';
}

final class PhoneticDisposedException extends PhoneticException {
  const PhoneticDisposedException([super.message = 'Phonetics was disposed']);

  @override
  String toString() => 'PhoneticDisposedException: $message';
}

final class PhoneticWorkerException extends PhoneticException {
  const PhoneticWorkerException(super.message);

  @override
  String toString() => 'PhoneticWorkerException: $message';
}
