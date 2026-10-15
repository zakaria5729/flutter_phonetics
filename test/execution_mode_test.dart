/// Author: Zakaria Hossain
/// Description: Tests validating cancelPrevious and queue execution modes.
library;

import 'dart:async';

import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

import 'support/workload.dart';

Future<void> wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  late Workload workload;

  setUpAll(
      () => workload = buildWorkload(PhoneticEngine(language: banglaLanguage)));

  Future<BanglaPhonetics> startedInstance(PhoneticExecutionMode mode) async {
    final phonetics = BanglaPhonetics(executionMode: mode);
    addTearDown(phonetics.dispose);
    await phonetics.similarity('আ', 'আ');
    return phonetics;
  }

  test('cancelPrevious is the default', () {
    final phonetics = BanglaPhonetics();
    addTearDown(phonetics.dispose);
    expect(phonetics.executionMode, PhoneticExecutionMode.cancelPrevious);
    expect(BanglaPhonetics.instance.executionMode,
        PhoneticExecutionMode.cancelPrevious);
  });

  group('setExecutionMode', () {
    test('changes the mode of a running instance', () async {
      final phonetics = await startedInstance(PhoneticExecutionMode.queue);

      final queuedFirst = phonetics.rank(heavyQuery, workload.names);
      final queuedSecond = phonetics.similarity('আসাদ', 'আছাদ');
      expect((await queuedFirst).error, isNull);
      expect((await queuedSecond).error, isNull);

      phonetics.setExecutionMode(PhoneticExecutionMode.cancelPrevious);
      expect(phonetics.executionMode, PhoneticExecutionMode.cancelPrevious);

      final replacedFirst = phonetics.rank(heavyQuery, workload.names);
      await wait(30);
      final replacedSecond = phonetics.similarity('আসাদ', 'আছাদ');
      expect((await replacedFirst).error, isA<PhoneticCancelledException>());
      expect((await replacedSecond).score, 85);

      phonetics.setExecutionMode(PhoneticExecutionMode.queue);
      final first = phonetics.rank(heavyQuery, workload.names);
      final second = phonetics.similarity('আসাদ', 'আছাদ');
      expect((await first).error, isNull);
      expect((await second).error, isNull);
    });

    test('works on BanglaPhonetics.instance', () async {
      final instance = BanglaPhonetics.instance;
      addTearDown(() =>
          instance.setExecutionMode(PhoneticExecutionMode.cancelPrevious));

      instance.setExecutionMode(PhoneticExecutionMode.queue);
      expect(instance.executionMode, PhoneticExecutionMode.queue);
      final first = instance.generateWords('আসাদ', minScore: 90);
      final second = instance.generateWords('শরীফ', minScore: 90);
      expect((await first).error, isNull);
      expect((await second).error, isNull);

      instance.setExecutionMode(PhoneticExecutionMode.cancelPrevious);
      expect(instance.executionMode, PhoneticExecutionMode.cancelPrevious);
    });

    test('on an instance with a setup error it changes nothing else', () async {
      final broken = BanglaPhonetics(gapSimilarity: 2);
      broken.setExecutionMode(PhoneticExecutionMode.queue);
      expect(broken.executionMode, PhoneticExecutionMode.queue);
      expect((await broken.generate('আসাদ')).error,
          isA<PhoneticArgumentException>());
    });
  });

  group('queue', () {
    test('a second call waits for the first, and both succeed', () async {
      final phonetics = await startedInstance(PhoneticExecutionMode.queue);
      final finishedOrder = <String>[];

      final first = phonetics
          .rank(heavyQuery, workload.names)
          .then((result) => finishedOrder.add('first'));
      await wait(30);
      final second = phonetics
          .similarity('আসাদ', 'আছাদ')
          .then((result) => finishedOrder.add('second'));
      await Future.wait([first, second]);

      expect(finishedOrder, ['first', 'second']);
    });

    test('nothing is cancelled', () async {
      final phonetics = await startedInstance(PhoneticExecutionMode.queue);
      final first = phonetics.rank(heavyQuery, workload.names);
      final second = phonetics.rank(heavyQuery, workload.names);
      expect((await first).error, isNull);
      expect((await second).error, isNull);
      expect((await second).matches.length, workload.names.length);
    });
  });

  group('cancelPrevious', () {
    const mode = PhoneticExecutionMode.cancelPrevious;

    test('a new call cancels the running one and starts at once', () async {
      final phonetics = await startedInstance(mode);
      final first = phonetics.rank(heavyQuery, workload.names);
      await wait(60);

      final stopwatch = Stopwatch()..start();
      final second = await phonetics.similarity('আসাদ', 'আছাদ');

      expect(second.error, isNull);
      expect(second.score, 85);
      expect(
          stopwatch.elapsedMilliseconds, lessThan(workload.directRunMs ~/ 3));
      final firstResult = await first;
      expect(firstResult.error, isA<PhoneticCancelledException>());
      expect(firstResult.matches, isEmpty);
    });

    test('with several quick calls only the last one finishes', () async {
      final phonetics = await startedInstance(mode);
      final first = phonetics.rank(heavyQuery, workload.names);
      final second = phonetics.rank(heavyQuery, workload.names);
      await wait(30);
      final third = phonetics.rank(heavyQuery, workload.names);

      expect((await first).error, isA<PhoneticCancelledException>());
      expect((await second).error, isA<PhoneticCancelledException>());
      final last = await third;
      expect(last.error, isNull);
      expect(last.matches.length, workload.names.length);
    });

    test('awaiting each call before the next cancels nothing', () async {
      final phonetics = await startedInstance(mode);
      for (var i = 0; i < 5; i++) {
        final (:words, :error) =
            await phonetics.generateWords('আসাদ', minScore: 90);
        expect(error, isNull);
        expect(words, ['আসাদ', 'আশাদ', 'আষাদ']);
      }
    });

    test('works across different calls on the same instance', () async {
      final phonetics = await startedInstance(mode);
      final ranking = phonetics.rank(heavyQuery, workload.names);
      await wait(30);
      final words = await phonetics.generateWords('আসাদ', minScore: 90);

      expect(words.error, isNull);
      expect(words.words, ['আসাদ', 'আশাদ', 'আষাদ']);
      expect((await ranking).error, isA<PhoneticCancelledException>());
    });

    test('a call that is already cancelled does not cancel the running one',
        () async {
      final phonetics = await startedInstance(mode);
      final running = phonetics.rank(heavyQuery, workload.names);
      await wait(30);

      final token = PhoneticCancelToken()..cancel();
      final skipped =
          await phonetics.similarity('আসাদ', 'আছাদ', cancelToken: token);
      expect(skipped.error, isA<PhoneticCancelledException>());

      expect((await running).error, isNull);
    });

    test('a call with invalid arguments does not cancel the running one',
        () async {
      final phonetics = await startedInstance(mode);
      final running = phonetics.rank(heavyQuery, workload.names);
      await wait(30);

      final invalid = await phonetics.generate('আসাদ', maxResults: 0);
      expect(invalid.error, isA<PhoneticArgumentException>());

      expect((await running).error, isNull);
    });

    test('tokens still work', () async {
      final phonetics = await startedInstance(mode);
      final token = PhoneticCancelToken();
      final running =
          phonetics.rank(heavyQuery, workload.names, cancelToken: token);
      await wait(30);
      token.cancel();
      expect((await running).error, isA<PhoneticCancelledException>());
      expect((await phonetics.similarity('আসাদ', 'আছাদ')).score, 85);
    });
  });
}
