/// Author: Zakaria Hossain
/// Description: Web Worker implementation for Flutter web platforms.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../cancel.dart';
import 'time_sliced_worker.dart';
import 'web_worker_script.g.dart';
import 'worker.dart';

PhoneticWorker createPhoneticWorker(Map<String, Object?> engineConfig) =>
    WebWorker(engineConfig);

class WebWorker extends RequestTrackingWorker {
  WebWorker(this._engineConfig, {String? scriptSource})
      : _scriptSource = scriptSource ?? webWorkerScript;

  final Map<String, Object?> _engineConfig;
  final String _scriptSource;
  web.Worker? _worker;
  String? _scriptUrl;
  TimeSlicedWorker? _fallback;

  @override
  String get name => _fallback?.name ?? 'web worker';

  @override
  Future<Object?> request(
    Map<String, Object?> request, {
    PhoneticCancelToken? cancelToken,
  }) {
    final fallback = _fallback;
    if (fallback != null && !isDisposed) {
      return fallback.request(request, cancelToken: cancelToken);
    }
    return super.request(request, cancelToken: cancelToken);
  }

  @override
  void sendRequest(int id, Map<String, Object?> request) {
    final worker = _worker ?? _startWorker();
    worker?.postMessage({...request, 'id': id}.jsify());
  }

  @override
  void sendCancel(int id) =>
      _worker?.postMessage({'op': 'cancel', 'id': id}.jsify());

  @override
  void sendCancelAll() => _worker?.postMessage({'op': 'cancelAll'}.jsify());

  @override
  void cancelAll() {
    super.cancelAll();
    _fallback?.cancelAll();
  }

  @override
  void onDispose() {
    _worker?.terminate();
    _worker = null;
    _revokeScriptUrl();
    final fallback = _fallback;
    if (fallback != null) unawaited(fallback.dispose());
  }

  web.Worker? _startWorker() {
    try {
      final script = web.Blob(
        [_scriptSource.toJS].toJS,
        web.BlobPropertyBag(type: 'text/javascript'),
      );
      final url = web.URL.createObjectURL(script);
      _scriptUrl = url;
      final worker = web.Worker(url.toJS);
      worker.onmessage = _handleMessage.toJS;
      worker.onerror = _handleError.toJS;
      worker.onmessageerror = _handleError.toJS;
      worker.postMessage(
          {'op': 'init', 'id': -1, 'config': _engineConfig}.jsify());
      return _worker = worker;
    } catch (_) {
      _switchToFallback();
      return null;
    }
  }

  void _handleMessage(web.MessageEvent event) {
    try {
      final data = event.data.dartify();
      if (data is! Map) return;
      if ((data['id'] as num?)?.toInt() == -1) {
        _revokeScriptUrl();
        return;
      }
      handleResponse(data);
    } catch (_) {
      _switchToFallback();
    }
  }

  void _handleError(web.Event event) {
    event.preventDefault();
    _switchToFallback();
  }

  void _switchToFallback() {
    _worker?.terminate();
    _worker = null;
    _revokeScriptUrl();
    final fallback = _fallback ??= TimeSlicedWorker(_engineConfig);
    for (final pending in takePendingRequests()) {
      fallback.request(pending.request, cancelToken: pending.cancelToken).then(
          pending.completer.complete,
          onError: pending.completer.completeError);
    }
  }

  void _revokeScriptUrl() {
    final url = _scriptUrl;
    if (url == null) return;
    web.URL.revokeObjectURL(url);
    _scriptUrl = null;
  }
}
