/// Author: Zakaria Hossain
/// Description: Cancellation token and listener management for async phonetic tasks.
library;

class PhoneticCancelToken {
  bool _isCancelled = false;
  List<void Function()>? _listeners;

  bool get isCancelled => _isCancelled;

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

  void addListener(void Function() listener) {
    if (_isCancelled) {
      try {
        listener();
      } catch (_) {}
    } else {
      (_listeners ??= []).add(listener);
    }
  }

  void removeListener(void Function() listener) => _listeners?.remove(listener);
}
