/// Author: Zakaria Hossain
/// Description: Cancellation token and listener management for async phonetic tasks.
library;

/// Lets the caller stop a running request.
class PhoneticCancelToken {
  bool _isCancelled = false;
  List<void Function()>? _listeners;

  /// Whether [cancel] has been called.
  bool get isCancelled => _isCancelled;

  /// Marks the token as cancelled and notifies the listeners once.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    final listeners = _listeners;
    _listeners = null;
    if (listeners == null) return;
    for (final listener in listeners) {
      try {
        listener();
      } catch (_) {}
    }
  }

  /// Calls [listener] when the token is cancelled, or right away if it already is.
  void addListener(void Function() listener) {
    if (_isCancelled) {
      try {
        listener();
      } catch (_) {}
    } else {
      (_listeners ??= []).add(listener);
    }
  }

  /// Stops [listener] from being called.
  void removeListener(void Function() listener) => _listeners?.remove(listener);
}
