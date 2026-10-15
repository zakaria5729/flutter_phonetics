/// Author: Zakaria Hossain
/// Description: Main-thread time-sliced worker fallback for environments blocking workers.
library;

import '../protocol/protocol.dart';
import 'worker.dart';

class TimeSlicedWorker extends RequestTrackingWorker {
  TimeSlicedWorker(
    this._engineConfig, {
    this.sliceDuration = const Duration(milliseconds: 4),
  });

  final Map<String, Object?> _engineConfig;
  final Duration sliceDuration;

  late final RequestProcessor _processor = RequestProcessor(
    decodeEngineConfig(_engineConfig),
    handleResponse,
    sliceDuration: sliceDuration,
  );

  @override
  String get name => 'main thread (time-sliced)';

  @override
  void sendRequest(int id, Map<String, Object?> request) =>
      _processor.onMessage({...request, 'id': id});

  @override
  void sendCancel(int id) => _processor.onMessage({'op': 'cancel', 'id': id});

  @override
  void sendCancelAll() => _processor.onMessage({'op': 'cancelAll'});

  @override
  void onDispose() => _processor.onMessage({'op': 'cancelAll'});
}
