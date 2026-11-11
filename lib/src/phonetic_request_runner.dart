import 'cancel.dart';
import 'errors.dart';
import 'execution_mode.dart';
import 'worker/worker.dart';

class PhoneticRequestRunner {
  PhoneticRequestRunner(this._worker, this._setupError, this.executionMode);

  factory PhoneticRequestRunner.failed(
          PhoneticException setupError, PhoneticExecutionMode executionMode) =>
      PhoneticRequestRunner(null, setupError, executionMode);

  factory PhoneticRequestRunner.start(
    Map<String, Object?> Function() buildWorkerConfig,
    PhoneticExecutionMode executionMode,
  ) {
    try {
      return PhoneticRequestRunner(
          createPhoneticWorker(buildWorkerConfig()), null, executionMode);
    } catch (error) {
      return PhoneticRequestRunner(
          null, PhoneticWorkerException('$error'), executionMode);
    }
  }

  PhoneticExecutionMode executionMode;
  final PhoneticWorker? _worker;
  final PhoneticException? _setupError;

  String get workerName => _worker?.name ?? 'unavailable';

  Future<({T? value, PhoneticException? error})> run<T>(
    Map<String, Object?> Function() buildRequest,
    PhoneticCancelToken? cancelToken,
    T Function(Object?) decode,
  ) async {
    final worker = _worker;
    if (worker == null) return (value: null, error: _setupError);

    final Map<String, Object?> request;
    try {
      request = buildRequest();
    } catch (error) {
      return (
        value: null,
        error:
            PhoneticArgumentException('could not read the arguments: $error'),
      );
    }

    try {
      final isCancelledAlready = cancelToken?.isCancelled ?? false;
      if (executionMode == PhoneticExecutionMode.cancelPrevious &&
          !isCancelledAlready) {
        worker.cancelAll();
      }
      final payload = await worker.request(request, cancelToken: cancelToken);
      return (value: decode(payload), error: null);
    } on PhoneticException catch (error) {
      return (value: null, error: error);
    } catch (error) {
      return (value: null, error: PhoneticWorkerException('$error'));
    }
  }

  void cancelAll() {
    try {
      _worker?.cancelAll();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _worker?.dispose();
    } catch (_) {}
  }
}
