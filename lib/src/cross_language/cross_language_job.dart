import '../core/engine.dart';
import '../core/models.dart';
import '../errors.dart';
import '../results.dart';
import 'cross_language_models.dart';

class ResultSide {
  ResultSide._(this.job, this.error);

  factory ResultSide.running(PhoneticJob<List<PhoneticMatch>> job) =>
      ResultSide._(job, null);

  factory ResultSide.failed(PhoneticException error) =>
      ResultSide._(null, error);

  factory ResultSide.notRequested() => ResultSide._(null, null);

  factory ResultSide.finishedWithNoMatches() =>
      ResultSide._(_FinishedJob<List<PhoneticMatch>>(const []), null);

  final PhoneticJob<List<PhoneticMatch>>? job;
  final PhoneticException? error;

  bool get isFinished => job == null || job!.isDone;

  PhoneticMatchesResult toMatchesResult() => (
        matches: error == null
            ? (job?.result ?? const <PhoneticMatch>[])
            : const <PhoneticMatch>[],
        error: error,
      );
}

class CrossLanguageJob extends PhoneticJob<CrossLanguageResult> {
  CrossLanguageJob(this._banglaSide, this._englishSide);

  final ResultSide _banglaSide;
  final ResultSide _englishSide;

  @override
  bool get isDone => _banglaSide.isFinished && _englishSide.isFinished;

  @override
  CrossLanguageResult get result => CrossLanguageResult(
        bangla: _banglaSide.toMatchesResult(),
        english: _englishSide.toMatchesResult(),
      );

  @override
  void advance(int workUnits) {
    final side = !_banglaSide.isFinished ? _banglaSide : _englishSide;
    side.job?.advance(workUnits);
  }
}

class _FinishedJob<T> extends PhoneticJob<T> {
  _FinishedJob(this._result);

  final T _result;

  @override
  bool get isDone => true;

  @override
  T get result => _result;

  @override
  void advance(int workUnits) {}
}
