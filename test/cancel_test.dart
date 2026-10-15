/// Author: Zakaria Hossain
/// Description: Tests verifying cancellation tokens and request preemption.
library;

import 'dart:async';

import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/protocol/protocol.dart';
import 'package:flutter_phonetics/src/worker/time_sliced_worker.dart';
import 'package:test/test.dart';

import 'support/workload.dart';

final throwsCancelled = throwsA(isA<PhoneticCancelledException>());

Future<void> wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  final engine = PhoneticEngine(language: banglaLanguage);
  late Workload workload;
  late BanglaPhonetics phonetics;

  setUpAll(() => workload = buildWorkload(engine));
  setUp(() async {
    phonetics = BanglaPhonetics(executionMode: PhoneticExecutionMode.queue);
    await phonetics.similarity('আ', 'আ');
  });
  tearDown(() => phonetics.dispose());

  Future<int> smallRequestMs() async {
    final stopwatch = Stopwatch()..start();
    expect((await phonetics.similarity('আসাদ', 'আছাদ')).score, 85);
    return stopwatch.elapsedMilliseconds;
  }

  group('PhoneticCancelToken', () {
    test('notifies listeners once and supports removal', () {
      final token = PhoneticCancelToken();
      var firstCalls = 0;
      var secondCalls = 0;
      void first() => firstCalls++;
      token.addListener(first);
      token.addListener(() => secondCalls++);
      token.removeListener(first);
      expect(token.isCancelled, isFalse);
      token.cancel();
      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(firstCalls, 0);
      expect(secondCalls, 1);
      token.addListener(first);
      expect(firstCalls, 1);
    });
  });

  test('an unused token changes nothing', () async {
    final token = PhoneticCancelToken();
    final (:words, :error) =
        await phonetics.generateWords('আসাদ', minScore: 90, cancelToken: token);
    expect(error, isNull);
    expect(words, ['আসাদ', 'আশাদ', 'আষাদ']);
    token.cancel();
  });

  test('a cancelled token returns at once and sends nothing', () async {
    final token = PhoneticCancelToken()..cancel();
    final (:matches, :error) =
        await phonetics.rank(heavyQuery, workload.names, cancelToken: token);
    expect(error, isA<PhoneticCancelledException>());
    expect(matches, isEmpty);
    expect(await smallRequestMs(), lessThan(workload.directRunMs ~/ 3));
  });

  test('cancel stops a job that is already running', () async {
    final token = PhoneticCancelToken();
    final call = phonetics.rank(heavyQuery, workload.names, cancelToken: token);
    await wait(60);
    token.cancel();
    final (:matches, :error) = await call;
    expect(error, isA<PhoneticCancelledException>());
    expect(matches, isEmpty);

    final elapsedMs = await smallRequestMs();
    expect(elapsedMs, lessThan(workload.directRunMs ~/ 3),
        reason: 'worker kept running the cancelled job ($elapsedMs ms)');
  });

  test('cancel drops a queued request without running it', () async {
    final singleRun = Stopwatch()..start();
    await phonetics.rank(heavyQuery, workload.names);
    final singleRunMs = singleRun.elapsedMilliseconds;

    final token = PhoneticCancelToken();
    final stopwatch = Stopwatch()..start();
    final first = phonetics.rank(heavyQuery, workload.names);
    final second =
        phonetics.rank(heavyQuery, workload.names, cancelToken: token);
    await wait(30);
    token.cancel();

    expect((await second).error, isA<PhoneticCancelledException>());
    final firstResult = await first;
    expect(firstResult.error, isNull);
    expect(firstResult.matches.length, workload.names.length);
    expect(await smallRequestMs(), lessThan(singleRunMs ~/ 3));
    expect(stopwatch.elapsedMilliseconds, lessThan(singleRunMs * 1.5));
  });

  test('one token cancels every request it was given to', () async {
    final token = PhoneticCancelToken();
    final rankCall =
        phonetics.rank(heavyQuery, workload.names, cancelToken: token);
    final generateCall = phonetics.generate('আসাদ', cancelToken: token);
    final similarityCall =
        phonetics.similarity('আসাদ', 'আছাদ', cancelToken: token);
    await wait(30);
    token.cancel();

    expect((await rankCall).error, isA<PhoneticCancelledException>());
    expect((await generateCall).error, isA<PhoneticCancelledException>());
    expect((await similarityCall).error, isA<PhoneticCancelledException>());
    expect(await smallRequestMs(), lessThan(workload.directRunMs ~/ 3));
  });

  test('cancelled calls return empty results', () async {
    final token = PhoneticCancelToken()..cancel();
    expect((await phonetics.generateWords('আসাদ', cancelToken: token)).words,
        isEmpty);
    expect(
        (await phonetics.similarity('আসাদ', 'আসাদ', cancelToken: token)).score,
        0);
    expect(
        (await phonetics.matches('আসাদ', 'আসাদ', cancelToken: token)).isMatch,
        isFalse);
  });

  test('cancelAll stops everything and keeps the instance usable', () async {
    final first = phonetics.rank(heavyQuery, workload.names);
    final second = phonetics.rank(heavyQuery, workload.names);
    await wait(40);
    phonetics.cancelAll();

    expect((await first).error, isA<PhoneticCancelledException>());
    expect((await second).error, isA<PhoneticCancelledException>());
    expect(await smallRequestMs(), lessThan(workload.directRunMs ~/ 3));
    expect((await phonetics.generateWords('আসাদ', minScore: 90)).words,
        ['আসাদ', 'আশাদ', 'আষাদ']);
  });

  test('dispose cancels pending work', () async {
    final disposable = BanglaPhonetics();
    await disposable.similarity('আ', 'আ');
    final call = disposable.rank(heavyQuery, workload.names);
    await wait(40);
    await disposable.dispose();
    expect((await call).error, isA<PhoneticCancelledException>());
    expect((await disposable.generate('আসাদ')).error,
        isA<PhoneticDisposedException>());
  });

  test('a cancelled request never answers a later one', () async {
    for (var i = 0; i < 20; i++) {
      final token = PhoneticCancelToken();
      final stale =
          phonetics.generate('শরীফ', maxResults: 200, cancelToken: token);
      final shouldCancel = i.isEven;
      if (shouldCancel) token.cancel();
      final fresh = await phonetics.generate('আসাদ', minScore: 90);
      expect(
          fresh.matches.map((match) => match.word), ['আসাদ', 'আশাদ', 'আষাদ']);
      expect((await stale).error, shouldCancel ? isNotNull : isNull);
    }
  });

  test('the time-sliced worker cancels running jobs too', () async {
    final worker = TimeSlicedWorker(encodeEngineConfig(engine));
    addTearDown(worker.dispose);
    final token = PhoneticCancelToken();
    final call = worker.request(
        rankRequest(heavyQuery, workload.names, 0, null),
        cancelToken: token);
    final failed = expectLater(call, throwsCancelled);
    await wait(30);
    token.cancel();
    await failed;

    final stopwatch = Stopwatch()..start();
    final similarity = await worker.request(similarityRequest('আসাদ', 'আছাদ'));
    expect(decodeSimilarity(similarity), 85);
    expect(stopwatch.elapsedMilliseconds, lessThan(workload.directRunMs ~/ 3));
  });
}
