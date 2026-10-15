/// Author: Zakaria Hossain
/// Description: High-level async interface managing isolate/web worker execution.
library;

import 'cancel.dart';
import 'core/models.dart';
import 'core/language.dart';
import 'core/rules.dart';
import 'core/validation.dart';
import 'errors.dart';
import 'execution_mode.dart';
import 'protocol/protocol.dart';
import 'results.dart';
import 'worker/worker.dart';

/// Finds sound-alike spellings of a word and scores how close two spellings are.
///
/// Work runs off the calling thread: in an isolate on Dart VM platforms and in a
/// Web Worker on the web. Every method returns a record holding the value and an
/// `error`; nothing is thrown.
class Phonetics {
  /// Creates an instance for [language].
  ///
  /// [rules] replaces the language's default rules. [gapSimilarity],
  /// [markGapSimilarity] and [unrelatedSimilarity] tune how missing letters, missing
  /// marks and unrelated letters are scored. [executionMode] decides what happens
  /// when a request arrives while another is still running.
  Phonetics({
    required PhoneticLanguage language,
    PhoneticRuleSet? rules,
    double gapSimilarity = 0.5,
    double markGapSimilarity = 0.85,
    double unrelatedSimilarity = 0.4,
    PhoneticExecutionMode executionMode = PhoneticExecutionMode.cancelPrevious,
  }) : this._(
          language,
          _setUp(language, rules, gapSimilarity, markGapSimilarity,
              unrelatedSimilarity),
          executionMode,
        );

  Phonetics._(this.language, _SetUp setUp, this._executionMode)
      : _worker = setUp.worker,
        _setupError = setUp.error;

  static _SetUp _setUp(
    PhoneticLanguage language,
    PhoneticRuleSet? rules,
    double gapSimilarity,
    double markGapSimilarity,
    double unrelatedSimilarity,
  ) {
    final engine = PhoneticEngine(
      language: language,
      rules: rules,
      gapSimilarity: gapSimilarity,
      markGapSimilarity: markGapSimilarity,
      unrelatedSimilarity: unrelatedSimilarity,
    );
    final setupError = engine.error;
    if (setupError != null) return _SetUp(null, setupError);
    try {
      return _SetUp(createPhoneticWorker(encodeEngineConfig(engine)), null);
    } catch (error) {
      return _SetUp(null, PhoneticWorkerException('$error'));
    }
  }

  /// The language this instance works with.
  final PhoneticLanguage language;
  PhoneticExecutionMode _executionMode;
  final PhoneticWorker? _worker;
  final PhoneticException? _setupError;

  /// The kind of worker running the requests, for example `isolate` or `web worker`.
  String get workerName => _worker?.name ?? 'unavailable';

  /// How overlapping requests are handled.
  PhoneticExecutionMode get executionMode => _executionMode;

  /// Changes how overlapping requests are handled, including on shared instances
  /// such as [BanglaPhonetics.instance].
  void setExecutionMode(PhoneticExecutionMode mode) {
    _executionMode = mode;
  }

  /// Generates spelling variants of [input] that sound alike, best match first.
  ///
  /// Only variants scoring at least [minScore] (0 to 100) are returned, up to
  /// [maxResults]; pass `null` for no limit. [includeOriginal] keeps the input in
  /// the list, [maxChanges] limits how many letters may differ, and [cancelToken]
  /// stops the request early.
  Future<PhoneticMatchesResult> generate(
    String input, {
    double minScore = 70,
    int? maxResults = 50,
    bool includeOriginal = true,
    int? maxChanges,
    PhoneticCancelToken? cancelToken,
  }) async {
    final invalid = generateArgumentError(minScore, maxResults, maxChanges);
    if (invalid != null) {
      return (matches: const <PhoneticMatch>[], error: invalid);
    }

    final result = await _run(
      () => generateRequest(
          input, minScore, maxResults, includeOriginal, maxChanges),
      cancelToken,
      decodeMatches,
    );
    return (
      matches: result.value ?? const <PhoneticMatch>[],
      error: result.error,
    );
  }

  /// Like [generate], but returns only the spellings without scores.
  Future<PhoneticWordsResult> generateWords(
    String input, {
    double minScore = 70,
    int? maxResults = 50,
    bool includeOriginal = true,
    int? maxChanges,
    PhoneticCancelToken? cancelToken,
  }) async {
    final result = await generate(
      input,
      minScore: minScore,
      maxResults: maxResults,
      includeOriginal: includeOriginal,
      maxChanges: maxChanges,
      cancelToken: cancelToken,
    );
    return (
      words: [for (final match in result.matches) match.word],
      error: result.error,
    );
  }

  /// Scores how alike [a] and [b] sound, from 0 to 100.
  Future<PhoneticSimilarityResult> similarity(
    String a,
    String b, {
    PhoneticCancelToken? cancelToken,
  }) async {
    final result = await _run(
        () => similarityRequest(a, b), cancelToken, decodeSimilarity);
    return (score: result.value ?? 0.0, error: result.error);
  }

  /// Tells whether [a] and [b] sound alike, meaning their similarity is at least
  /// [minScore].
  Future<PhoneticMatchCheckResult> matches(
    String a,
    String b, {
    double minScore = 80,
    PhoneticCancelToken? cancelToken,
  }) async {
    final invalid = minScoreError(minScore);
    if (invalid != null) return (isMatch: false, error: invalid);

    final result = await similarity(a, b, cancelToken: cancelToken);
    return (isMatch: result.score >= minScore, error: result.error);
  }

  /// Orders [candidates] by how closely they sound like [query].
  ///
  /// Candidates scoring below [minScore] are dropped, and [limit] keeps only the
  /// best ones.
  Future<PhoneticMatchesResult> rank(
    String query,
    Iterable<String> candidates, {
    double minScore = 0,
    int? limit,
    PhoneticCancelToken? cancelToken,
  }) async {
    final invalid = rankArgumentError(minScore, limit);
    if (invalid != null) {
      return (matches: const <PhoneticMatch>[], error: invalid);
    }

    final result = await _run(
      () => rankRequest(
          query, candidates.toList(growable: false), minScore, limit),
      cancelToken,
      decodeMatches,
    );
    return (
      matches: result.value ?? const <PhoneticMatch>[],
      error: result.error,
    );
  }

  /// Cancels every request that has not finished yet.
  void cancelAll() {
    try {
      _worker?.cancelAll();
    } catch (_) {}
  }

  /// Stops the background worker. Later calls return a disposed error.
  Future<void> dispose() async {
    try {
      await _worker?.dispose();
    } catch (_) {}
  }

  Future<({T? value, PhoneticException? error})> _run<T>(
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
      if (_executionMode == PhoneticExecutionMode.cancelPrevious &&
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
}

class _SetUp {
  _SetUp(this.worker, this.error);

  final PhoneticWorker? worker;
  final PhoneticException? error;
}
