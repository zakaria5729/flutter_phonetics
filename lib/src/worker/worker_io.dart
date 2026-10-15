/// Author: Zakaria Hossain
/// Description: Background isolate worker implementation for VM platforms.
library;

import 'dart:async';
import 'dart:isolate';

import '../errors.dart';
import '../protocol/protocol.dart';
import 'worker.dart';

PhoneticWorker createPhoneticWorker(Map<String, Object?> engineConfig) =>
    IsolateWorker(engineConfig);

class IsolateWorker extends RequestTrackingWorker {
  IsolateWorker(this._engineConfig, {this.entryPoint = runIsolate});

  final Map<String, Object?> _engineConfig;
  final void Function(List<Object?> arguments) entryPoint;
  Future<SendPort>? _startFuture;
  SendPort? _isolatePort;
  RawReceivePort? _receivePort;
  Isolate? _isolate;

  @override
  String get name => 'isolate';

  @override
  void sendRequest(int id, Map<String, Object?> request) {
    _ensureStarted().then((port) {
      if (!isPending(id)) return;
      try {
        _receivePort?.keepIsolateAlive = true;
        port.send({...request, 'id': id});
      } catch (error) {
        failRequest(id, error);
      }
    }, onError: (Object error) => failRequest(id, error));
  }

  @override
  void sendCancel(int id) => _isolatePort?.send({'op': 'cancel', 'id': id});

  @override
  void sendCancelAll() => _isolatePort?.send({'op': 'cancelAll'});

  @override
  void onNoPendingRequests() => _receivePort?.keepIsolateAlive = false;

  @override
  void onDispose() => _shutDown();

  Future<SendPort> _ensureStarted() {
    final existing = _startFuture;
    if (existing != null) return existing;
    final starting = _spawn();
    _startFuture = starting;
    starting.then((_) {}, onError: (Object _) {
      if (identical(_startFuture, starting)) _startFuture = null;
    });
    return starting;
  }

  Future<SendPort> _spawn() async {
    final ready = Completer<SendPort>();
    final receivePort = RawReceivePort();
    _receivePort = receivePort;
    receivePort.handler = (Object? message) {
      if (message is SendPort) {
        _isolatePort = message;
        ready.complete(message);
      } else if (message is Map) {
        handleResponse(message);
      } else if (message is List) {
        _handleCrash('${message.first}', ready);
      } else if (message == null) {
        _handleCrash('background isolate exited', ready);
      }
    };
    try {
      _isolate = await Isolate.spawn<List<Object?>>(
        entryPoint,
        [receivePort.sendPort, _engineConfig],
        onError: receivePort.sendPort,
        onExit: receivePort.sendPort,
        errorsAreFatal: true,
        debugName: 'flutter_phonetics',
      );
    } catch (_) {
      receivePort.close();
      _receivePort = null;
      rethrow;
    }
    return ready.future;
  }

  void _handleCrash(String reason, Completer<SendPort> ready) {
    final error = PhoneticWorkerException(reason);
    if (!ready.isCompleted) ready.completeError(error);
    _shutDown();
    failAllRequests(error);
  }

  void _shutDown() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _isolatePort = null;
    _startFuture = null;
  }
}

void runIsolate(List<Object?> arguments) {
  final mainPort = arguments[0]! as SendPort;
  final engine = decodeEngineConfig(arguments[1]! as Map);
  final processor = RequestProcessor(engine, mainPort.send);
  final receivePort = RawReceivePort();
  receivePort.handler =
      (Object? message) => processor.onMessage(message! as Map);
  mainPort.send(receivePort.sendPort);
}
