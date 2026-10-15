/// Author: Zakaria Hossain
/// Description: Platform-conditional worker factory interface.
library;

import 'dart:async';

import '../cancel.dart';
import '../errors.dart';

export 'worker_unsupported.dart'
    if (dart.library.js_interop) 'worker_web.dart'
    if (dart.library.io) 'worker_io.dart';

abstract class PhoneticWorker {
  String get name;

  Future<Object?> request(
    Map<String, Object?> request, {
    PhoneticCancelToken? cancelToken,
  });

  void cancelAll();

  Future<void> dispose();
}

class PendingRequest {
  PendingRequest(this.request, this.cancelToken);

  final Map<String, Object?> request;
  final PhoneticCancelToken? cancelToken;
  final Completer<Object?> completer = Completer<Object?>();
  void Function()? _cancelListener;
}

abstract class RequestTrackingWorker implements PhoneticWorker {
  final Map<int, PendingRequest> _pendingRequests = {};
  int _nextRequestId = 0;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  bool isPending(int id) => _pendingRequests.containsKey(id);

  void sendRequest(int id, Map<String, Object?> request);

  void sendCancel(int id) {}

  void sendCancelAll() {}

  void onNoPendingRequests() {}

  void onDispose() {}

  @override
  Future<Object?> request(
    Map<String, Object?> request, {
    PhoneticCancelToken? cancelToken,
  }) {
    if (_isDisposed) {
      return Future.error(const PhoneticDisposedException());
    }
    if (cancelToken != null && cancelToken.isCancelled) {
      return Future.error(const PhoneticCancelledException());
    }
    final id = _nextRequestId++;
    final pending = PendingRequest(request, cancelToken);
    _pendingRequests[id] = pending;
    if (cancelToken != null) {
      void onCancel() => _cancelRequest(id);
      pending._cancelListener = onCancel;
      cancelToken.addListener(onCancel);
    }
    try {
      sendRequest(id, request);
    } catch (error) {
      failRequest(id, error);
    }
    return pending.completer.future;
  }

  PendingRequest? _removePending(int id) {
    final pending = _pendingRequests.remove(id);
    if (pending == null) return null;
    final listener = pending._cancelListener;
    if (listener != null) pending.cancelToken?.removeListener(listener);
    if (_pendingRequests.isEmpty) onNoPendingRequests();
    return pending;
  }

  void handleResponse(Map<Object?, Object?> response) {
    final id = (response['id'] as num?)?.toInt();
    if (id == null) return;
    final pending = _removePending(id);
    if (pending == null) return;
    if (response['ok'] == true) {
      pending.completer.complete(response['result']);
    } else {
      pending.completer
          .completeError(PhoneticWorkerException('${response['error']}'));
    }
  }

  void failRequest(int id, Object error) =>
      _removePending(id)?.completer.completeError(error);

  void failAllRequests(Object error) {
    for (final id in List.of(_pendingRequests.keys)) {
      failRequest(id, error);
    }
  }

  List<PendingRequest> takePendingRequests() => [
        for (final id in List.of(_pendingRequests.keys))
          if (_removePending(id) case final pending?) pending,
      ];

  void _cancelRequest(int id) {
    final pending = _removePending(id);
    if (pending == null) return;
    pending.completer.completeError(const PhoneticCancelledException());
    try {
      sendCancel(id);
    } catch (_) {}
  }

  @override
  void cancelAll() {
    if (_pendingRequests.isEmpty) return;
    failAllRequests(const PhoneticCancelledException());
    try {
      sendCancelAll();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    onDispose();
    failAllRequests(const PhoneticCancelledException('Phonetics was disposed'));
  }
}
