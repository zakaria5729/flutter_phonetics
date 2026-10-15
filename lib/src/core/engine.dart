/// Author: Zakaria Hossain
/// Description: Core phonetic search engine implementing best-first variant generation.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../errors.dart';
import '../results.dart';
import 'language.dart';
import 'models.dart';
import 'rules.dart';
import 'text_normalizer.dart';
import 'word_boundary.dart';
import 'validation.dart';

const _noLimit = 0x3FFFFFFF;
const _resultCeiling = 100000;
const _outputCharacterBudget = 20000000;

int _resultLimit(int? requested, int inputLength) => math.min(
    math.min(requested ?? _resultCeiling, _resultCeiling),
    _outputCharacterBudget ~/ math.max(inputLength, 1));

class PhoneticEngine {
  PhoneticEngine({
    required this.language,
    PhoneticRuleSet? rules,
    this.gapSimilarity = 0.5,
    this.markGapSimilarity = 0.85,
    this.unrelatedSimilarity = 0.4,
  })  : rules = rules ?? PhoneticRuleSet.forLanguage(language),
        _logGap = math.log(gapSimilarity),
        _logMarkGap = math.log(markGapSimilarity),
        _logUnrelated = math.log(unrelatedSimilarity),
        error = _settingsError(
            language,
            rules ?? PhoneticRuleSet.forLanguage(language),
            gapSimilarity,
            markGapSimilarity,
            unrelatedSimilarity);

  final PhoneticLanguage language;
  final PhoneticRuleSet rules;
  final double gapSimilarity;
  final double markGapSimilarity;
  final double unrelatedSimilarity;
  final PhoneticArgumentException? error;

  final double _logGap;
  final double _logMarkGap;
  final double _logUnrelated;

  PhoneticMatchesResult generate(
    String input, {
    double minScore = 70,
    int? maxResults = 50,
    bool includeOriginal = true,
    int? maxChanges,
  }) {
    final problem =
        error ?? generateArgumentError(minScore, maxResults, maxChanges);
    if (problem != null) {
      return (matches: const <PhoneticMatch>[], error: problem);
    }
    try {
      final job = createGenerateJob(
          this, input, minScore, maxResults, includeOriginal, maxChanges);
      return (matches: job.run(), error: null);
    } catch (failure) {
      return (
        matches: const <PhoneticMatch>[],
        error: PhoneticWorkerException('$failure'),
      );
    }
  }

  PhoneticWordsResult generateWords(
    String input, {
    double minScore = 70,
    int? maxResults = 50,
    bool includeOriginal = true,
    int? maxChanges,
  }) {
    final result = generate(
      input,
      minScore: minScore,
      maxResults: maxResults,
      includeOriginal: includeOriginal,
      maxChanges: maxChanges,
    );
    return (
      words: [for (final match in result.matches) match.word],
      error: result.error,
    );
  }

  PhoneticSimilarityResult similarity(String a, String b) {
    final problem = error;
    if (problem != null) return (score: 0.0, error: problem);
    try {
      final first = language.normalize(a);
      final second = language.normalize(b);
      if (first == second) return (score: 100.0, error: null);
      if (first.isEmpty || second.isEmpty) return (score: 0.0, error: null);
      final logScore = _SimilarityScorer(this, first)
          .logScoreAgainst(second, double.negativeInfinity);
      return (score: _toPercent(logScore), error: null);
    } catch (failure) {
      return (score: 0.0, error: PhoneticWorkerException('$failure'));
    }
  }

  PhoneticMatchCheckResult matches(String a, String b, {double minScore = 80}) {
    final problem = minScoreError(minScore);
    if (problem != null) return (isMatch: false, error: problem);
    final result = similarity(a, b);
    return (isMatch: result.score >= minScore, error: result.error);
  }

  PhoneticMatchesResult rank(
    String query,
    Iterable<String> candidates, {
    double minScore = 0,
    int? limit,
  }) {
    final problem = error ?? rankArgumentError(minScore, limit);
    if (problem != null) {
      return (matches: const <PhoneticMatch>[], error: problem);
    }
    final List<String> candidateList;
    try {
      candidateList = candidates.toList(growable: false);
    } catch (failure) {
      return (
        matches: const <PhoneticMatch>[],
        error: PhoneticArgumentException(
            'could not read the candidates: $failure'),
      );
    }
    try {
      final job = createRankJob(this, query, candidateList, minScore, limit);
      return (matches: job.run(), error: null);
    } catch (failure) {
      return (
        matches: const <PhoneticMatch>[],
        error: PhoneticWorkerException('$failure'),
      );
    }
  }

  static PhoneticArgumentException? _settingsError(PhoneticLanguage language,
      PhoneticRuleSet rules, double gap, double markGap, double unrelated) {
    final problems = <String>[
      if (language.error != null) language.error!.message,
      if (rules.languageCode != language.code)
        'the rules are for language "${rules.languageCode}" but the engine '
            'uses "${language.code}"',
      if (!_isFraction(gap)) 'gapSimilarity must be between 0 and 1 (got $gap)',
      if (!_isFraction(markGap))
        'markGapSimilarity must be between 0 and 1 (got $markGap)',
      if (!_isFraction(unrelated))
        'unrelatedSimilarity must be between 0 and 1 (got $unrelated)',
      if (rules.error != null) rules.error!.message,
    ];
    return problems.isEmpty
        ? null
        : PhoneticArgumentException(problems.join('; '));
  }

  static bool _isFraction(double value) =>
      !value.isNaN && value > 0 && value < 1;
}

GenerateJob createGenerateJob(
  PhoneticEngine engine,
  String input,
  double minScore,
  int? maxResults,
  bool includeOriginal,
  int? maxChanges,
) =>
    GenerateJob._(
        engine, input, minScore, maxResults, includeOriginal, maxChanges);

RankJob createRankJob(PhoneticEngine engine, String query,
        List<String> candidates, double minScore, int? limit) =>
    RankJob._(engine, query, candidates, minScore, limit);

const _roundingTolerance = 0.005;

double _logCutoffFor(double minScore) {
  final lowest = minScore - _roundingTolerance;
  return lowest <= 0 ? double.negativeInfinity : math.log(lowest / 100);
}

double _toPercent(double logScore) => logScore == double.negativeInfinity
    ? 0
    : (math.exp(logScore) * 10000).roundToDouble() / 100;

abstract class PhoneticJob<T> {
  bool get isDone;

  T get result;

  void advance(int workUnits);

  T run() {
    while (!isDone) {
      advance(_noLimit);
    }
    return result;
  }
}

class _SearchState {
  _SearchState({
    required this.parent,
    required this.slot,
    required this.alternativeNumber,
    required this.logScore,
    required this.changeCount,
    required this.order,
  });

  final _SearchState? parent;
  final int slot;
  final int alternativeNumber;
  final double logScore;
  final int changeCount;
  final int order;
}

class _Slot {
  _Slot(this.start, this.spelling, this.alternatives);

  final int start;
  final String spelling;
  final List<PhoneticAlternative> alternatives;
}

// Best-first search. A state has at most three children and none of them
// scores higher than its parent, so every combination is reached once and
// results come out in descending score order.
class GenerateJob extends PhoneticJob<List<PhoneticMatch>> {
  GenerateJob._(
    PhoneticEngine engine,
    String input,
    double minScore,
    int? maxResults,
    bool includeOriginal,
    int? maxChanges,
  )   : _normalizer = engine.language.normalizer,
        _input = engine.language.normalize(input),
        _letterCase = engine.language.normalizer.detectCase(input),
        _minScore = minScore,
        _logCutoff = _logCutoffFor(minScore),
        _maxResults = _resultLimit(maxResults, input.length),
        _includeOriginal = includeOriginal,
        _maxChanges = maxChanges ?? _noLimit,
        _maxExpansions = _resultLimit(maxResults, input.length) * 16 + 1024 {
    if (_input.isEmpty) {
      _isDone = true;
      return;
    }
    _findSlots(engine.rules);
    _queue.push(_SearchState(
      parent: null,
      slot: -1,
      alternativeNumber: 0,
      logScore: 0,
      changeCount: 0,
      order: _createdCount++,
    ));
  }

  final TextNormalizer _normalizer;
  final String _input;
  final LetterCase _letterCase;
  final double _minScore;
  final double _logCutoff;
  final int _maxResults;
  final bool _includeOriginal;
  final int _maxChanges;
  final int _maxExpansions;

  final List<_Slot> _slots = [];
  final _Heap<_SearchState> _queue = _Heap<_SearchState>((a, b) =>
      a.logScore > b.logScore ||
      (a.logScore == b.logScore && a.order < b.order));
  final Set<String> _seenWords = {};
  final List<PhoneticMatch> _results = [];
  final List<_SearchState> _changedStates = [];
  int _createdCount = 0;
  int _expansions = 0;
  bool _isDone = false;

  void _findSlots(PhoneticRuleSet rules) {
    final found = <_Slot>[];
    var index = 0;
    while (index < _input.length) {
      var length = 1;
      List<PhoneticAlternative>? alternatives;
      for (var candidateLength =
              math.min(rules.longestSpellingLength, _input.length - index);
          candidateLength >= 1;
          candidateLength--) {
        final options = rules.alternativesFor(
          _input.substring(index, index + candidateLength),
          atWordStart: startsWord(_input, index),
          atWordEnd: endsWord(_input, index + candidateLength),
          generating: true,
        );
        if (options.isNotEmpty) {
          length = candidateLength;
          alternatives = options;
          break;
        }
      }
      if (alternatives != null) {
        found.add(_Slot(
            index, _input.substring(index, index + length), alternatives));
      }
      index += length;
    }
    found.sort((a, b) {
      final bySimilarity = b.alternatives.first.similarity
          .compareTo(a.alternatives.first.similarity);
      return bySimilarity != 0 ? bySimilarity : a.start.compareTo(b.start);
    });
    _slots.addAll(found);
  }

  @override
  bool get isDone => _isDone;

  @override
  List<PhoneticMatch> get result => _results;

  @override
  void advance(int workUnits) {
    var done = 0;
    while (!_isDone && done < workUnits) {
      if (_queue.isEmpty) {
        _isDone = true;
        break;
      }
      final state = _queue.pop();
      done++;
      _expansions++;
      final score = _toPercent(state.logScore);
      if (score < _minScore) {
        _isDone = true;
        break;
      }
      _addResult(state, score);
      if (_results.length >= _maxResults || _expansions >= _maxExpansions) {
        _isDone = true;
        break;
      }
      _pushChildren(state);
    }
  }

  void _addResult(_SearchState state, double score) {
    if (state.slot < 0) {
      _seenWords.add(_input);
      if (_includeOriginal) {
        _results.add(
            PhoneticMatch(_normalizer.applyCase(_input, _letterCase), 100));
      }
      return;
    }

    _changedStates.clear();
    for (_SearchState? current = state;
        current != null;
        current = current.parent) {
      _changedStates.add(current);
    }
    _changedStates
        .sort((a, b) => _slots[a.slot].start.compareTo(_slots[b.slot].start));

    final buffer = StringBuffer();
    var cursor = 0;
    for (final changed in _changedStates) {
      final slot = _slots[changed.slot];
      buffer
        ..write(_input.substring(cursor, slot.start))
        ..write(slot.alternatives[changed.alternativeNumber - 1].text);
      cursor = slot.start + slot.spelling.length;
    }
    buffer.write(_input.substring(cursor));

    final word = buffer.toString();
    if (!_seenWords.add(word)) return;

    _results
        .add(PhoneticMatch(_normalizer.applyCase(word, _letterCase), score, [
      for (final changed in _changedStates)
        PhoneticChange(
          position: _slots[changed.slot].start,
          from: _slots[changed.slot].spelling,
          to: _slots[changed.slot]
              .alternatives[changed.alternativeNumber - 1]
              .text,
          similarity: _slots[changed.slot]
              .alternatives[changed.alternativeNumber - 1]
              .similarity,
        ),
    ]));
  }

  void _pushChildren(_SearchState state) {
    if (_slots.isEmpty) return;

    if (state.slot < 0) {
      if (_maxChanges > 0) {
        _pushState(null, 0, 1, _slots[0].alternatives[0].logSimilarity, 1);
      }
      return;
    }

    final slotIndex = state.slot;
    final alternativeNumber = state.alternativeNumber;
    final alternatives = _slots[slotIndex].alternatives;

    if (alternativeNumber < alternatives.length) {
      _pushState(
        state.parent,
        slotIndex,
        alternativeNumber + 1,
        state.logScore -
            alternatives[alternativeNumber - 1].logSimilarity +
            alternatives[alternativeNumber].logSimilarity,
        state.changeCount,
      );
    }
    if (slotIndex + 1 < _slots.length) {
      final nextSlotLogSimilarity =
          _slots[slotIndex + 1].alternatives[0].logSimilarity;
      if (state.changeCount < _maxChanges) {
        _pushState(state, slotIndex + 1, 1,
            state.logScore + nextSlotLogSimilarity, state.changeCount + 1);
      }
      if (alternativeNumber == 1) {
        _pushState(
          state.parent,
          slotIndex + 1,
          1,
          state.logScore -
              alternatives[0].logSimilarity +
              nextSlotLogSimilarity,
          state.changeCount,
        );
      }
    }
  }

  void _pushState(_SearchState? parent, int slot, int alternativeNumber,
      double logScore, int changeCount) {
    if (logScore < _logCutoff) return;
    _queue.push(_SearchState(
      parent: parent,
      slot: slot,
      alternativeNumber: alternativeNumber,
      logScore: logScore,
      changeCount: changeCount,
      order: _createdCount++,
    ));
  }
}

class RankJob extends PhoneticJob<List<PhoneticMatch>> {
  factory RankJob._(PhoneticEngine engine, String query,
      List<String> candidates, double minScore, int? limit) {
    final normalizer = engine.language.normalizer;
    final normalizedQuery = normalizer.normalize(query);
    return RankJob._withScorer(
      normalizer,
      normalizedQuery,
      normalizedQuery.isEmpty
          ? null
          : _SimilarityScorer(engine, normalizedQuery),
      candidates,
      minScore,
      limit,
    );
  }

  RankJob._withScorer(this._normalizer, this._query, this._scorer,
      this._candidates, this._minScore, this._limit)
      : _minLogCutoff = _logCutoffFor(_minScore),
        _logCutoff = _logCutoffFor(_minScore);

  final TextNormalizer _normalizer;
  final String _query;
  final _SimilarityScorer? _scorer;
  final List<String> _candidates;
  final double _minScore;
  final int? _limit;
  final double _minLogCutoff;
  double _logCutoff;

  final Set<String> _seenCandidates = {};
  final List<PhoneticMatch> _allMatches = [];
  final _Heap<PhoneticMatch> _topMatches = _Heap<PhoneticMatch>((a, b) =>
      a.score < b.score ||
      (a.score == b.score && a.word.compareTo(b.word) > 0));
  int _nextCandidate = 0;
  bool _isDone = false;
  List<PhoneticMatch> _result = const [];

  @override
  bool get isDone => _isDone;

  @override
  List<PhoneticMatch> get result => _result;

  @override
  void advance(int workUnits) {
    var done = 0;
    while (!_isDone && done < workUnits) {
      if (_nextCandidate >= _candidates.length) {
        _finish();
        return;
      }
      final candidate = _candidates[_nextCandidate++];
      if (!_seenCandidates.add(candidate)) continue;
      done++;

      final normalized = _normalizer.normalize(candidate);
      final scorer = _scorer;
      final double score;
      if (normalized == _query) {
        score = 100;
      } else if (normalized.isEmpty || scorer == null) {
        score = 0;
      } else {
        score = _toPercent(scorer.logScoreAgainst(normalized, _logCutoff));
      }
      if (score < _minScore) continue;

      final match = PhoneticMatch(candidate, score);
      final limit = _limit;
      if (limit == null) {
        _allMatches.add(match);
      } else if (_topMatches.length < limit) {
        _topMatches.push(match);
        if (_topMatches.length == limit) _raiseCutoff();
      } else if (_topMatches.hasHigherPriority(_topMatches.peek, match)) {
        _topMatches.replaceTop(match);
        _raiseCutoff();
      }
    }
  }

  void _raiseCutoff() {
    _logCutoff = math.max(_minLogCutoff, _logCutoffFor(_topMatches.peek.score));
  }

  void _finish() {
    final matches = _limit == null ? _allMatches : _topMatches.drain();
    matches.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.word.compareTo(b.word);
    });
    _result = matches;
    _isDone = true;
  }
}

class _RuleMove {
  const _RuleMove(this.fromLength, this.to, this.logSimilarity);

  final int fromLength;
  final String to;
  final double logSimilarity;
}

class _SimilarityScorer {
  _SimilarityScorer(this._engine, this._query)
      : _normalizer = _engine.language.normalizer,
        _dropCosts = Float64List(_query.length),
        _ruleMoves = List<List<_RuleMove>?>.filled(_query.length, null),
        _rowCount = _engine.rules.longestSpellingLength + 1,
        _rowBestScores = Float64List(_engine.rules.longestSpellingLength + 1) {
    final longestSpelling = _engine.rules.longestSpellingLength;
    for (var start = 0; start < _query.length; start++) {
      _dropCosts[start] = _normalizer.isMark(_query.codeUnitAt(start))
          ? _engine._logMarkGap
          : _engine._logGap;
      List<_RuleMove>? moves;
      for (var length = 1;
          length <= longestSpelling && start + length <= _query.length;
          length++) {
        final spelling = _query.substring(start, start + length);
        final alternatives = _engine.rules.alternativesFor(
          spelling,
          atWordStart: startsWord(_query, start),
          atWordEnd: endsWord(_query, start + length),
        );
        for (final alternative in alternatives) {
          (moves ??= []).add(
              _RuleMove(length, alternative.text, alternative.logSimilarity));
        }
      }
      _ruleMoves[start] = moves;
    }
  }

  final PhoneticEngine _engine;
  final TextNormalizer _normalizer;
  final String _query;
  final Float64List _dropCosts;
  final List<List<_RuleMove>?> _ruleMoves;
  final int _rowCount;
  final Float64List _rowBestScores;
  List<Float64List> _rows = const [];

  double logScoreAgainst(String other, double logCutoff) {
    const unreachable = double.negativeInfinity;
    final queryLength = _query.length;
    final otherLength = other.length;
    final lookAhead = _rowCount - 1;
    final logGap = _engine._logGap;
    final logMarkGap = _engine._logMarkGap;
    final logUnrelated = _engine._logUnrelated;
    final checkCutoff = logCutoff != unreachable;

    if (_rows.isEmpty || _rows[0].length < otherLength + 1) {
      _rows = List.generate(_rowCount, (_) => Float64List(otherLength + 1));
    }
    final rows = _rows;
    for (var row = 0; row < _rowCount; row++) {
      rows[row].fillRange(0, otherLength + 1, unreachable);
      _rowBestScores[row] = unreachable;
    }
    rows[0][0] = 0;

    for (var queryIndex = 0;; queryIndex++) {
      final currentRow = rows[queryIndex % _rowCount];
      final hasQueryUnit = queryIndex < queryLength;
      final nextRowIndex = (queryIndex + 1) % _rowCount;
      final nextRow = rows[nextRowIndex];
      final queryUnit = hasQueryUnit ? _query.codeUnitAt(queryIndex) : -1;
      final dropCost = hasQueryUnit ? _dropCosts[queryIndex] : 0.0;
      final moves = hasQueryUnit ? _ruleMoves[queryIndex] : null;

      for (var otherIndex = 0; otherIndex <= otherLength; otherIndex++) {
        final score = currentRow[otherIndex];
        if (score == unreachable) continue;
        final otherUnit =
            otherIndex < otherLength ? other.codeUnitAt(otherIndex) : -1;

        if (otherIndex < otherLength) {
          final inserted =
              score + (_normalizer.isMark(otherUnit) ? logMarkGap : logGap);
          if (inserted > currentRow[otherIndex + 1]) {
            currentRow[otherIndex + 1] = inserted;
          }
        }
        if (!hasQueryUnit) continue;

        var candidate = score + dropCost;
        if (candidate > nextRow[otherIndex]) {
          nextRow[otherIndex] = candidate;
          if (candidate > _rowBestScores[nextRowIndex]) {
            _rowBestScores[nextRowIndex] = candidate;
          }
        }
        if (otherIndex < otherLength) {
          candidate = score + (queryUnit == otherUnit ? 0.0 : logUnrelated);
          if (candidate > nextRow[otherIndex + 1]) {
            nextRow[otherIndex + 1] = candidate;
            if (candidate > _rowBestScores[nextRowIndex]) {
              _rowBestScores[nextRowIndex] = candidate;
            }
          }
        }
        if (moves != null) {
          for (final move in moves) {
            final endIndex = otherIndex + move.to.length;
            if (endIndex > otherLength ||
                !_matchesAt(other, move.to, otherIndex)) {
              continue;
            }
            final targetRowIndex = (queryIndex + move.fromLength) % _rowCount;
            final targetRow = rows[targetRowIndex];
            candidate = score + move.logSimilarity;
            if (candidate > targetRow[endIndex]) {
              targetRow[endIndex] = candidate;
              if (candidate > _rowBestScores[targetRowIndex]) {
                _rowBestScores[targetRowIndex] = candidate;
              }
            }
          }
        }
      }

      if (!hasQueryUnit) return currentRow[otherLength];

      // Scores only fall along a path and every path to the end passes
      // through one of the next few rows, so their best bounds the result.
      if (checkCutoff) {
        var frontier = unreachable;
        for (var ahead = 1;
            ahead <= lookAhead && queryIndex + ahead <= queryLength;
            ahead++) {
          final best = _rowBestScores[(queryIndex + ahead) % _rowCount];
          if (best > frontier) frontier = best;
        }
        if (frontier < logCutoff) return unreachable;
      }

      currentRow.fillRange(0, otherLength + 1, unreachable);
      _rowBestScores[queryIndex % _rowCount] = unreachable;
    }
  }

  static bool _matchesAt(String text, String piece, int start) {
    for (var i = 0; i < piece.length; i++) {
      if (text.codeUnitAt(start + i) != piece.codeUnitAt(i)) return false;
    }
    return true;
  }
}

class _Heap<T> {
  _Heap(this.hasHigherPriority);

  final bool Function(T a, T b) hasHigherPriority;
  final List<T> _items = [];

  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  T get peek => _items.first;

  void push(T item) {
    _items.add(item);
    _siftUp(_items.length - 1);
  }

  T pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _siftDown(0);
    }
    return top;
  }

  void replaceTop(T item) {
    _items[0] = item;
    _siftDown(0);
  }

  List<T> drain() {
    final items = List<T>.of(_items);
    _items.clear();
    return items;
  }

  void _siftUp(int index) {
    final item = _items[index];
    while (index > 0) {
      final parent = (index - 1) >> 1;
      if (!hasHigherPriority(item, _items[parent])) break;
      _items[index] = _items[parent];
      index = parent;
    }
    _items[index] = item;
  }

  void _siftDown(int index) {
    final count = _items.length;
    final item = _items[index];
    while (true) {
      final left = 2 * index + 1;
      if (left >= count) break;
      final right = left + 1;
      final child =
          (right < count && hasHigherPriority(_items[right], _items[left]))
              ? right
              : left;
      if (!hasHigherPriority(_items[child], item)) break;
      _items[index] = _items[child];
      index = child;
    }
    _items[index] = item;
  }
}
