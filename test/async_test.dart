/// Author: Zakaria Hossain
/// Description: Tests verifying asynchronous worker execution and variant generation.
library;

import 'dart:async';

import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/protocol/protocol.dart';
import 'package:flutter_phonetics/src/worker/time_sliced_worker.dart';
import 'package:test/test.dart';

import 'support/workload.dart';

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

void main() {
  late BanglaPhonetics phonetics;
  final engine = PhoneticEngine(language: banglaLanguage);

  setUp(() =>
      phonetics = BanglaPhonetics(executionMode: PhoneticExecutionMode.queue));
  tearDown(() => phonetics.dispose());

  test('runs on a background thread', () async {
    await phonetics.similarity('আসাদ', 'আশাদ');
    expect(phonetics.workerName, _isWeb ? 'web worker' : 'isolate');
  });

  test('generate matches the engine', () async {
    final (:matches, :error) = await phonetics.generate('আসাদ', minScore: 90);
    expect(error, isNull);
    expect([for (final match in matches) match.word], ['আসাদ', 'আশাদ', 'আষাদ']);
    expect([for (final match in matches) match.score], [100, 95, 95]);
    expect(matches[1].changes.single.to, 'শ');

    for (final word in ['শরীফ', 'ক্ষমাশীল', 'মোহাম্মদ']) {
      final fromWorker =
          (await phonetics.generate(word, maxResults: 200)).matches;
      final direct = engine.generate(word, maxResults: 200).matches;
      expect(fromWorker, direct);
      expect([for (final match in fromWorker) match.changes],
          [for (final match in direct) match.changes]);
    }

    final unlimited =
        await phonetics.generate('আসাদ', minScore: 90, maxResults: null);
    expect(unlimited.matches.length, 3);

    final limited =
        await phonetics.generate('আসাদ', minScore: 80, maxResults: 2);
    expect(limited.matches.length, 2);
  });

  test('generateWords, similarity, matches and rank', () async {
    expect((await phonetics.generateWords('আসাদ', minScore: 90)).words,
        ['আসাদ', 'আশাদ', 'আষাদ']);
    expect((await phonetics.similarity('আসাদ', 'আছাদ')).score, 85);
    expect((await phonetics.matches('আসাদ', 'আচাদ')).isMatch, isFalse);
    expect((await phonetics.matches('আসাদ', 'আছাদ')).isMatch, isTrue);

    final ranked =
        await phonetics.rank('আসাদ', ['করিম', 'আছাদ', 'আশাদ'], minScore: 80);
    expect(ranked.error, isNull);
    expect(ranked.matches,
        const [PhoneticMatch('আশাদ', 95), PhoneticMatch('আছাদ', 85)]);
  });

  test('concurrent requests come back to the right callers', () async {
    final words = ['আসাদ', 'শরীফ', 'রহিম', 'নাজনীন', 'কৃষক', 'জসীম'];
    final calls = [
      for (var i = 0; i < 60; i++)
        phonetics.generateWords(words[i % words.length], minScore: 70),
    ];
    final results = await Future.wait(calls);
    for (var i = 0; i < results.length; i++) {
      expect(results[i].words,
          engine.generateWords(words[i % words.length], minScore: 70).words);
    }
  });

  test('custom rules reach the worker', () async {
    final custom = BanglaPhonetics(
      rules: banglaLanguage.defaultRuleSet.extend([
        const PhoneticRule(['ম', 'ন'], 0.6)
      ]),
    );
    addTearDown(custom.dispose);
    expect((await custom.generate('আসাম', minScore: 0)).matches,
        contains(const PhoneticMatch('আসান', 60)));
  });

  test('main thread keeps running during heavy work', () async {
    final names = buildNames(20000);
    await phonetics.similarity('আ', 'আ');

    final stopwatch = Stopwatch()..start();
    engine.rank(heavyQuery, names);
    final directRunMs = stopwatch.elapsedMilliseconds;

    var ticks = 0;
    final timer =
        Timer.periodic(const Duration(milliseconds: 1), (_) => ticks++);
    final result = await phonetics.rank(heavyQuery, names);
    timer.cancel();

    expect(result.matches.length, names.length);
    expect(directRunMs, greaterThan(30));
    expect(ticks, greaterThan(5));
  });

  group('time-sliced worker', () {
    test('gives the same results and yields to the event loop', () async {
      final worker = TimeSlicedWorker(encodeEngineConfig(engine));
      addTearDown(worker.dispose);
      final flatMatches =
          await worker.request(generateRequest('শরীফ', 50, 200, true, null));
      expect(decodeMatches(flatMatches),
          engine.generate('শরীফ', minScore: 50, maxResults: 200).matches);

      var ticks = 0;
      final timer = Timer.periodic(Duration.zero, (_) => ticks++);
      await worker.request(rankRequest(heavyQuery, buildNames(10000), 0, null));
      timer.cancel();
      expect(ticks, greaterThan(3));
    });
  });
}
