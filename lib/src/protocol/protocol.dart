/// Author: Zakaria Hossain
/// Description: Serialization protocol and request processing for workers.
library;

import 'dart:async';
import 'dart:collection';

import '../core/engine.dart';
import '../core/language.dart';
import '../core/models.dart';
import '../core/rules.dart';
import '../core/validation.dart';
import '../cross_language/cross_language_engine.dart';
import '../cross_language/cross_language_models.dart';
import '../errors.dart';
import '../results.dart';

export '../core/engine.dart' show PhoneticEngine, PhoneticJob;

Map<String, Object?> encodeEngineConfig(PhoneticEngine engine) => {
      'language': engine.language.toJson(),
      'rules': engine.rules.toJson(),
      'gap': engine.gapSimilarity,
      'markGap': engine.markGapSimilarity,
      'unrelated': engine.unrelatedSimilarity,
    };

PhoneticEngine decodeEngineConfig(Map<Object?, Object?> config) {
  final language = PhoneticLanguage.fromJson(config['language']);
  return PhoneticEngine(
    language: language,
    rules: PhoneticRuleSet.fromJson(config['rules'], language: language),
    gapSimilarity: _numberOrNaN(config['gap']),
    markGapSimilarity: _numberOrNaN(config['markGap']),
    unrelatedSimilarity: _numberOrNaN(config['unrelated']),
  );
}

double _numberOrNaN(Object? value) =>
    value is num ? value.toDouble() : double.nan;

typedef JobFactory = PhoneticJob<Object?> Function(
    Map<Object?, Object?> request);

const _crossLanguageConfigKind = 'cross';

Map<String, Object?> encodeCrossLanguageConfig(PhoneticEngine banglaEngine) => {
      'kind': _crossLanguageConfigKind,
      'bangla': encodeEngineConfig(banglaEngine),
    };

JobFactory decodeJobFactory(Map<Object?, Object?> config) {
  if (config['kind'] == _crossLanguageConfigKind) {
    final banglaConfig = config['bangla'];
    final engine = CrossLanguageEngine.fromBanglaEngine(
        decodeEngineConfig(banglaConfig is Map ? banglaConfig : const {}));
    return (request) => createCrossLanguageJob(engine, request);
  }
  final engine = decodeEngineConfig(config);
  return (request) => createJob(engine, request);
}

Map<String, Object?> generateRequest(String input, double minScore,
        int? maxResults, bool includeOriginal, int? maxChanges) =>
    {
      'op': 'generate',
      'input': input,
      'minScore': minScore,
      'maxResults': maxResults,
      'includeOriginal': includeOriginal,
      'maxChanges': maxChanges,
    };

Map<String, Object?> similarityRequest(String a, String b) =>
    {'op': 'similarity', 'a': a, 'b': b};

Map<String, Object?> rankRequest(
        String query, List<String> candidates, double minScore, int? limit) =>
    {
      'op': 'rank',
      'query': query,
      'candidates': candidates,
      'minScore': minScore,
      'limit': limit,
    };

Map<String, Object?> crossGenerateRequest(
  String input, {
  required bool wantsBangla,
  required bool wantsEnglish,
  required PhoneticSearchOptions banglaOptions,
  required PhoneticSearchOptions englishOptions,
}) =>
    {
      'op': 'crossGenerate',
      'input': input,
      'wantsBangla': wantsBangla,
      'wantsEnglish': wantsEnglish,
      'bangla': _searchOptionsToMap(banglaOptions),
      'english': _searchOptionsToMap(englishOptions),
    };

Map<String, Object?> _searchOptionsToMap(PhoneticSearchOptions options) => {
      'minScore': options.minScore,
      'maxResults': options.maxResults,
      'includeOriginal': options.includeOriginal,
      'maxChanges': options.maxChanges,
    };

PhoneticSearchOptions _searchOptionsFromMap(Object? map) {
  final fields = map! as Map;
  return PhoneticSearchOptions(
    minScore: (fields['minScore']! as num).toDouble(),
    maxResults: (fields['maxResults'] as num?)?.toInt(),
    includeOriginal: fields['includeOriginal']! as bool,
    maxChanges: (fields['maxChanges'] as num?)?.toInt(),
  );
}

PhoneticJob<Object?> createCrossLanguageJob(
    CrossLanguageEngine engine, Map<Object?, Object?> request) {
  if (request['op'] != 'crossGenerate') {
    throw PhoneticArgumentException('unknown operation: ${request['op']}');
  }
  final wantsBangla = request['wantsBangla']! as bool;
  final wantsEnglish = request['wantsEnglish']! as bool;
  final banglaOptions = _searchOptionsFromMap(request['bangla']);
  final englishOptions = _searchOptionsFromMap(request['english']);
  final problem = crossLanguageOptionsError(
    wantsBangla: wantsBangla,
    wantsEnglish: wantsEnglish,
    banglaOptions: banglaOptions,
    englishOptions: englishOptions,
  );
  if (problem != null) throw problem;
  return _EncodedJob(
    engine.createJob(
      request['input']! as String,
      wantsBangla: wantsBangla,
      wantsEnglish: wantsEnglish,
      banglaOptions: banglaOptions,
      englishOptions: englishOptions,
    ),
    _encodeCrossLanguageResult,
  );
}

const _argumentErrorKind = 'argument';
const _workerErrorKind = 'worker';

List<Object?> _encodeCrossLanguageResult(CrossLanguageResult result) => [
      _encodeResultSide(result.bangla),
      _encodeResultSide(result.english),
    ];

List<Object?> _encodeResultSide(PhoneticMatchesResult side) {
  final error = side.error;
  return [
    switch (error) {
      null => null,
      PhoneticArgumentException() => _argumentErrorKind,
      _ => _workerErrorKind,
    },
    error?.message,
    _flattenMatches(side.matches),
  ];
}

CrossLanguageResult decodeCrossLanguageResult(Object? payload) {
  final sides = payload! as List;
  return CrossLanguageResult(
    bangla: _decodeResultSide(sides[0]),
    english: _decodeResultSide(sides[1]),
  );
}

PhoneticMatchesResult _decodeResultSide(Object? encoded) {
  final side = encoded! as List;
  final kind = side[0] as String?;
  final message = side[1] as String?;
  final PhoneticException? error = switch (kind) {
    null => null,
    _argumentErrorKind => PhoneticArgumentException(message ?? ''),
    _ => PhoneticWorkerException(message ?? ''),
  };
  return (matches: decodeMatches(side[2]), error: error);
}

PhoneticJob<Object?> createJob(
    PhoneticEngine engine, Map<Object?, Object?> request) {
  final setupError = engine.error;
  if (setupError != null) throw setupError;

  switch (request['op']) {
    case 'generate':
      final minScore = (request['minScore']! as num).toDouble();
      final maxResults = (request['maxResults'] as num?)?.toInt();
      final maxChanges = (request['maxChanges'] as num?)?.toInt();
      final problem = generateArgumentError(minScore, maxResults, maxChanges);
      if (problem != null) throw problem;
      return _EncodedJob(
        createGenerateJob(
          engine,
          request['input']! as String,
          minScore,
          maxResults,
          request['includeOriginal']! as bool,
          maxChanges,
        ),
        _flattenMatches,
      );
    case 'rank':
      final minScore = (request['minScore']! as num).toDouble();
      final limit = (request['limit'] as num?)?.toInt();
      final problem = rankArgumentError(minScore, limit);
      if (problem != null) throw problem;
      return _EncodedJob(
        createRankJob(
          engine,
          request['query']! as String,
          [
            for (final candidate in request['candidates']! as List)
              candidate as String,
          ],
          minScore,
          limit,
        ),
        _flattenMatches,
      );
    case 'similarity':
      return _InstantJob(() {
        final result =
            engine.similarity(request['a']! as String, request['b']! as String);
        final problem = result.error;
        if (problem != null) throw problem;
        return result.score;
      });
    default:
      throw PhoneticArgumentException('unknown operation: ${request['op']}');
  }
}

// Per match: word, score, change count, then position, from, to and
// similarity for each change.
List<Object?> _flattenMatches(List<PhoneticMatch> matches) {
  final flat = <Object?>[];
  for (final match in matches) {
    flat
      ..add(match.word)
      ..add(match.score)
      ..add(match.changes.length);
    for (final change in match.changes) {
      flat
        ..add(change.position)
        ..add(change.from)
        ..add(change.to)
        ..add(change.similarity);
    }
  }
  return flat;
}

List<PhoneticMatch> decodeMatches(Object? flat) {
  final data = flat! as List;
  final matches = <PhoneticMatch>[];
  var index = 0;
  while (index < data.length) {
    final word = data[index++]! as String;
    final score = (data[index++]! as num).toDouble();
    final changeCount = (data[index++]! as num).toInt();
    final changes = changeCount == 0
        ? const <PhoneticChange>[]
        : List<PhoneticChange>.generate(changeCount, (_) {
            final change = PhoneticChange(
              position: (data[index]! as num).toInt(),
              from: data[index + 1]! as String,
              to: data[index + 2]! as String,
              similarity: (data[index + 3]! as num).toDouble(),
            );
            index += 4;
            return change;
          }, growable: false);
    matches.add(PhoneticMatch(word, score, changes));
  }
  return matches;
}

double decodeSimilarity(Object? value) => (value! as num).toDouble();

class _EncodedJob<T> extends PhoneticJob<Object?> {
  _EncodedJob(this._job, this._encode);

  final PhoneticJob<T> _job;
  final Object? Function(T) _encode;
  Object? _result;
  bool _isDone = false;

  @override
  bool get isDone => _isDone;

  @override
  Object? get result => _result;

  @override
  void advance(int workUnits) {
    if (_isDone) return;
    _job.advance(workUnits);
    if (_job.isDone) {
      _result = _encode(_job.result);
      _isDone = true;
    }
  }
}

class _InstantJob extends PhoneticJob<Object?> {
  _InstantJob(this._compute);

  final Object? Function() _compute;
  Object? _result;
  bool _isDone = false;

  @override
  bool get isDone => _isDone;

  @override
  Object? get result => _result;

  @override
  void advance(int workUnits) {
    if (_isDone) return;
    _result = _compute();
    _isDone = true;
  }
}

const _workUnitsPerSlice = 16;

class RequestProcessor {
  RequestProcessor(
    PhoneticEngine engine,
    void Function(Map<String, Object?> response) sendResponse, {
    Duration sliceDuration = const Duration(milliseconds: 8),
  }) : this.withJobFactory(
            (request) => createJob(engine, request), sendResponse,
            sliceDuration: sliceDuration);

  RequestProcessor.fromConfig(
    Map<Object?, Object?> config,
    void Function(Map<String, Object?> response) sendResponse, {
    Duration sliceDuration = const Duration(milliseconds: 8),
  }) : this.withJobFactory(decodeJobFactory(config), sendResponse,
            sliceDuration: sliceDuration);

  RequestProcessor.withJobFactory(
    this._createJob,
    this._sendResponse, {
    this.sliceDuration = const Duration(milliseconds: 8),
  });

  final JobFactory _createJob;
  final Duration sliceDuration;
  final void Function(Map<String, Object?> response) _sendResponse;
  final Queue<Map<Object?, Object?>> _queue = Queue();
  Object? _runningRequestId;
  bool _runningCancelled = false;
  bool _isProcessing = false;

  void onMessage(Map<Object?, Object?> message) {
    switch (message['op']) {
      case 'cancel':
        final id = message['id'];
        if (_isProcessing && id == _runningRequestId) {
          _runningCancelled = true;
        } else {
          _queue.removeWhere((queued) => queued['id'] == id);
        }
      case 'cancelAll':
        _queue.clear();
        if (_isProcessing) _runningCancelled = true;
      default:
        _queue.add(message);
        unawaited(_processQueue());
    }
  }

  void _deliver(Object? id, Map<String, Object?> response) {
    try {
      _sendResponse(response);
    } catch (error) {
      try {
        _sendResponse({'id': id, 'ok': false, 'error': error.toString()});
      } catch (_) {}
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      while (_queue.isNotEmpty) {
        final request = _queue.removeFirst();
        final id = request['id'];
        _runningRequestId = id;
        _runningCancelled = false;
        Map<String, Object?>? response;
        try {
          final job = _createJob(request);
          final sliceTimer = Stopwatch()..start();
          while (!job.isDone && !_runningCancelled) {
            job.advance(_workUnitsPerSlice);
            if (!job.isDone && sliceTimer.elapsed >= sliceDuration) {
              await Future<void>.delayed(Duration.zero);
              sliceTimer.reset();
            }
          }
          if (!_runningCancelled) {
            response = {'id': id, 'ok': true, 'result': job.result};
          }
        } catch (error) {
          response = {'id': id, 'ok': false, 'error': error.toString()};
        }
        _runningRequestId = null;
        if (response != null) _deliver(id, response);
      }
    } finally {
      _isProcessing = false;
    }
  }
}
