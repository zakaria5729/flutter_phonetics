import 'dart:async';

import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/protocol/protocol.dart';
import 'package:flutter_phonetics/src/worker/time_sliced_worker.dart';
import 'package:test/test.dart';

import '../support/cross_language_support.dart';
import '../support/cross_language_workload.dart';

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

Future<void> wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

final throwsCancelled = throwsA(isA<PhoneticCancelledException>());

void expectSameResult(
    CrossLanguageResult actual, CrossLanguageResult expected) {
  expect(actual.bangla.matches, expected.bangla.matches);
  expect(actual.english.matches, expected.english.matches);
  expect([for (final match in actual.bangla.matches) match.changes],
      [for (final match in expected.bangla.matches) match.changes]);
  expect([for (final match in actual.english.matches) match.changes],
      [for (final match in expected.english.matches) match.changes]);
  expect(actual.bangla.error.runtimeType, expected.bangla.error.runtimeType);
  expect(actual.english.error.runtimeType, expected.english.error.runtimeType);
  expect(actual.bangla.error?.message, expected.bangla.error?.message);
  expect(actual.english.error?.message, expected.english.error?.message);
}

void main() {
  late CrossLanguageWorkload workload;
  late CrossLanguagePhonetics phonetics;

  setUpAll(() => workload = buildCrossLanguageWorkload(crossLanguageEngine));
  setUp(() async {
    phonetics =
        CrossLanguagePhonetics(executionMode: PhoneticExecutionMode.queue);
    await phonetics.generate('Masud', maxResults: 1);
  });
  tearDown(() => phonetics.dispose());

  Future<int> smallRequestMs() async {
    final stopwatch = Stopwatch()..start();
    final result = await phonetics.generate('Masud', minScore: 95);
    expect(result.error, isNull);
    expect(result.english.matches.first.word, 'Masud');
    return stopwatch.elapsedMilliseconds;
  }

  test('the workload outlasts the waits used by the cancellation tests', () {
    expect(workload.directRunMs, greaterThan(150));
  });

  test('runs on a background thread', () {
    expect(phonetics.workerName, _isWeb ? 'web worker' : 'isolate');
  });

  group('results', () {
    test('equal the synchronous engine', () async {
      const names = [
        'মাসুদ',
        'Masud',
        'Abdul Karim',
        'মোহাম্মদ আব্দুল',
        'Hossain'
      ];
      for (final name in names) {
        for (final languages in [bothLanguages, banglaOnly, englishOnly]) {
          for (final maxChanges in [null, 1]) {
            final fromWorker = await phonetics.generate(name,
                languages: languages, minScore: 60, maxChanges: maxChanges);
            final direct = crossLanguageEngine.generate(name,
                languages: languages, minScore: 60, maxChanges: maxChanges);
            expectSameResult(fromWorker, direct);
          }
        }
      }
    });

    test('keep per-language options separate', () async {
      const banglaOptions = PhoneticSearchOptions(minScore: 99, maxResults: 5);
      const englishOptions = PhoneticSearchOptions(
          minScore: 85, maxResults: 3, includeOriginal: false);
      final fromWorker = await phonetics.generate('Masud',
          banglaOptions: banglaOptions, englishOptions: englishOptions);
      final direct = crossLanguageEngine.generate('Masud',
          banglaOptions: banglaOptions, englishOptions: englishOptions);
      expectSameResult(fromWorker, direct);
      expect(fromWorker.english.matches.length, 3);
    });

    test('reproduce the documented examples', () async {
      final bangla = await phonetics.generate('মাসুদ', minScore: 90);
      expect([for (final match in bangla.english.matches) match.word],
          ['Masud', 'Masood', 'Masoud', 'Mashud']);
      final english = await phonetics.generate('Masud', minScore: 90);
      expect([for (final match in english.bangla.matches) match.word].take(5),
          ['মাসুদ', 'মাসূদ', 'মাসুড', 'মসুদ', 'মাশুদ']);
    });

    test('unrequested lists stay empty without an error', () async {
      final result = await phonetics.generate('Masud', languages: banglaOnly);
      expect(result.english.matches, isEmpty);
      expect(result.english.error, isNull);
      expect(result.bangla.matches, isNotEmpty);
    });

    test('a long name matches the engine under a result limit', () async {
      final fromWorker = await phonetics.generate(workload.input,
          minScore: 40, maxResults: 120);
      final direct = crossLanguageEngine.generate(workload.input,
          minScore: 40, maxResults: 120);
      expectSameResult(fromWorker, direct);
    });

    test('concurrent requests come back to the right callers', () async {
      const names = ['Masud', 'মাসুদ', 'Rahim', 'রহিম', 'Karim', 'করিম'];
      final calls = [
        for (var i = 0; i < 30; i++)
          phonetics.generate(names[i % names.length], minScore: 70),
      ];
      final results = await Future.wait(calls);
      for (var i = 0; i < results.length; i++) {
        expectSameResult(
            results[i],
            crossLanguageEngine.generate(names[i % names.length],
                minScore: 70));
      }
    });
  });

  group('errors', () {
    test('invalid arguments fail both lists before reaching the worker',
        () async {
      final result = await phonetics.generate('Masud', minScore: 101);
      expect(result.bangla.error, isA<PhoneticArgumentException>());
      expect(result.english.error, same(result.bangla.error));
      expect(result.bangla.matches, isEmpty);

      final empty = await phonetics.generate('Masud', languages: {});
      expect(empty.error, isA<PhoneticArgumentException>());
    });

    test('per-list errors travel with the result', () async {
      final result = await phonetics.generate('Masud😀');
      expect(result.bangla.error, isA<PhoneticArgumentException>());
      expect(result.bangla.error!.message, contains('U+D83D'));
      expect(result.english.error, isNull);
      expect(result.english.matches, isNotEmpty);

      final bangla = await phonetics.generate('মাসুদ😀');
      expect(bangla.english.error, isA<PhoneticArgumentException>());
      expect(bangla.bangla.error, isNull);

      final unsupported = await phonetics.generate('123');
      expect(unsupported.bangla.error, isA<PhoneticArgumentException>());
      expect(unsupported.english.error, isA<PhoneticArgumentException>());
    });

    test('empty input gives empty lists and no error', () async {
      final result = await phonetics.generate('   ');
      expect(result.error, isNull);
      expect(result.bangla.matches, isEmpty);
      expect(result.english.matches, isEmpty);
    });

    test('custom Bangla rules reach the worker', () async {
      final custom = CrossLanguagePhonetics(
        banglaRules: banglaLanguage.defaultRuleSet.extend([
          const PhoneticRule(['ম', 'ন'], 0.6)
        ]),
      );
      addTearDown(custom.dispose);
      final result = await custom.generate('আসাম', minScore: 0);
      expect(result.bangla.matches, contains(const PhoneticMatch('আসান', 60)));
    });

    test('a broken Bangla setting fails only the Bangla list', () async {
      final broken = CrossLanguagePhonetics(gapSimilarity: 2);
      addTearDown(broken.dispose);
      final banglaInput = await broken.generate('মাসুদ');
      expect(banglaInput.bangla.error, isA<PhoneticArgumentException>());
      expect(banglaInput.english.error, isNull);
      expect(banglaInput.english.matches.first.word, 'Masud');
    });

    test('a disposed instance fails both lists', () async {
      final disposable = CrossLanguagePhonetics();
      await disposable.generate('Masud', maxResults: 1);
      await disposable.dispose();
      final result = await disposable.generate('Masud');
      expect(result.bangla.error, isA<PhoneticDisposedException>());
      expect(result.english.error, isA<PhoneticDisposedException>());
      disposable.cancelAll();
    });
  });

  group('cancellation', () {
    test('an unused token changes nothing', () async {
      final token = PhoneticCancelToken();
      final result =
          await phonetics.generate('মাসুদ', minScore: 90, cancelToken: token);
      expect(result.error, isNull);
      expect(result.english.matches.length, 4);
      token.cancel();
    });

    test('a cancelled token returns at once and sends nothing', () async {
      final token = PhoneticCancelToken()..cancel();
      final result = await phonetics.generate(workload.input,
          minScore: 0, maxResults: null, cancelToken: token);
      expect(result.bangla.error, isA<PhoneticCancelledException>());
      expect(result.english.error, isA<PhoneticCancelledException>());
      expect(result.bangla.matches, isEmpty);
      expect(await smallRequestMs(), lessThan(workload.directRunMs ~/ 3));
    });

    test('cancel stops a job that is already running', () async {
      final token = PhoneticCancelToken();
      final call = phonetics.generate(workload.input,
          minScore: 0, maxResults: null, cancelToken: token);
      await wait(60);
      token.cancel();
      final result = await call;
      expect(result.error, isA<PhoneticCancelledException>());
      expect(result.english.error, same(result.bangla.error));
      expect(result.english.matches, isEmpty);
      expect(await smallRequestMs(), lessThan(workload.directRunMs ~/ 3));
    });

    test('cancelAll stops everything and keeps the instance usable', () async {
      final first =
          phonetics.generate(workload.input, minScore: 0, maxResults: null);
      final second =
          phonetics.generate(workload.input, minScore: 0, maxResults: null);
      await wait(40);
      phonetics.cancelAll();

      expect((await first).error, isA<PhoneticCancelledException>());
      expect((await second).error, isA<PhoneticCancelledException>());
      expect(await smallRequestMs(), lessThan(workload.directRunMs ~/ 3));
    });

    test('dispose cancels pending work', () async {
      final disposable = CrossLanguagePhonetics();
      await disposable.generate('Masud', maxResults: 1);
      final call =
          disposable.generate(workload.input, minScore: 0, maxResults: null);
      await wait(40);
      await disposable.dispose();
      expect((await call).error, isA<PhoneticCancelledException>());
      expect((await disposable.generate('Masud')).error,
          isA<PhoneticDisposedException>());
    });

    test('a cancelled request never answers a later one', () async {
      for (var i = 0; i < 20; i++) {
        final token = PhoneticCancelToken();
        final stale =
            phonetics.generate('মোহাম্মদ', maxResults: 100, cancelToken: token);
        final shouldCancel = i.isEven;
        if (shouldCancel) token.cancel();
        final fresh = await phonetics.generate('Masud', minScore: 95);
        expect(fresh.english.matches.first.word, 'Masud');
        expect((await stale).error, shouldCancel ? isNotNull : isNull);
      }
    });
  });

  group('execution modes', () {
    Future<CrossLanguagePhonetics> started(PhoneticExecutionMode mode) async {
      final instance = CrossLanguagePhonetics(executionMode: mode);
      addTearDown(instance.dispose);
      await instance.generate('Masud', maxResults: 1);
      return instance;
    }

    test('cancelPrevious is the default', () {
      final instance = CrossLanguagePhonetics();
      addTearDown(instance.dispose);
      expect(instance.executionMode, PhoneticExecutionMode.cancelPrevious);
      expect(CrossLanguagePhonetics.instance.executionMode,
          PhoneticExecutionMode.cancelPrevious);
    });

    test('setExecutionMode changes the mode of a running instance', () async {
      final instance = await started(PhoneticExecutionMode.queue);
      instance.setExecutionMode(PhoneticExecutionMode.cancelPrevious);
      expect(instance.executionMode, PhoneticExecutionMode.cancelPrevious);
      instance.setExecutionMode(PhoneticExecutionMode.queue);
      expect(instance.executionMode, PhoneticExecutionMode.queue);
    });

    test('queue runs a second call after the first and cancels nothing',
        () async {
      final instance = await started(PhoneticExecutionMode.queue);
      final finishedOrder = <String>[];
      final first = instance
          .generate(workload.input, minScore: 0, maxResults: null)
          .then((result) {
        finishedOrder.add('first');
        return result;
      });
      await wait(30);
      final second = instance.generate('Masud', minScore: 95).then((result) {
        finishedOrder.add('second');
        return result;
      });
      final results = await Future.wait([first, second]);
      expect(finishedOrder, ['first', 'second']);
      expect(results[0].error, isNull);
      expect(results[1].error, isNull);
    });

    test('cancelPrevious cancels the running call and starts at once',
        () async {
      final instance = await started(PhoneticExecutionMode.cancelPrevious);
      final first =
          instance.generate(workload.input, minScore: 0, maxResults: null);
      await wait(60);

      final stopwatch = Stopwatch()..start();
      final second = await instance.generate('Masud', minScore: 95);

      expect(second.error, isNull);
      expect(second.english.matches.first.word, 'Masud');
      expect(
          stopwatch.elapsedMilliseconds, lessThan(workload.directRunMs ~/ 3));
      final firstResult = await first;
      expect(firstResult.error, isA<PhoneticCancelledException>());
      expect(firstResult.bangla.matches, isEmpty);
    });

    test('with several quick calls only the last one finishes', () async {
      final instance = await started(PhoneticExecutionMode.cancelPrevious);
      final first =
          instance.generate(workload.input, minScore: 0, maxResults: null);
      final second =
          instance.generate(workload.input, minScore: 0, maxResults: null);
      await wait(30);
      final third =
          instance.generate(workload.input, minScore: 0, maxResults: 50);

      expect((await first).error, isA<PhoneticCancelledException>());
      expect((await second).error, isA<PhoneticCancelledException>());
      final last = await third;
      expect(last.error, isNull);
      expect(last.bangla.matches, isNotEmpty);
    });

    test('a call with invalid arguments does not cancel the running one',
        () async {
      final instance = await started(PhoneticExecutionMode.cancelPrevious);
      final running =
          instance.generate(workload.input, minScore: 0, maxResults: null);
      await wait(30);

      final invalid = await instance.generate('Masud', maxResults: 0);
      expect(invalid.error, isA<PhoneticArgumentException>());

      expect((await running).error, isNull);
    });

    test('awaiting each call before the next cancels nothing', () async {
      final instance = await started(PhoneticExecutionMode.cancelPrevious);
      for (var i = 0; i < 5; i++) {
        final result = await instance.generate('মাসুদ', minScore: 90);
        expect(result.error, isNull);
        expect(result.english.matches.length, 4);
      }
    });
  });

  group('time-sliced worker', () {
    final config =
        encodeCrossLanguageConfig(PhoneticEngine(language: banglaLanguage));

    test('gives the same results and yields to the event loop', () async {
      final worker = TimeSlicedWorker(config);
      addTearDown(worker.dispose);
      final payload = await worker.request(crossGenerateRequest('Masud',
          wantsBangla: true,
          wantsEnglish: true,
          banglaOptions: const PhoneticSearchOptions(minScore: 60),
          englishOptions: const PhoneticSearchOptions(minScore: 60)));
      expectSameResult(decodeCrossLanguageResult(payload),
          crossLanguageEngine.generate('Masud', minScore: 60));

      var ticks = 0;
      final timer = Timer.periodic(Duration.zero, (_) => ticks++);
      await worker.request(crossGenerateRequest(workload.input,
          wantsBangla: true,
          wantsEnglish: true,
          banglaOptions:
              const PhoneticSearchOptions(minScore: 0, maxResults: null),
          englishOptions:
              const PhoneticSearchOptions(minScore: 0, maxResults: null)));
      timer.cancel();
      expect(ticks, greaterThan(3));
    });

    test('cancels running jobs too', () async {
      final worker = TimeSlicedWorker(config);
      addTearDown(worker.dispose);
      final token = PhoneticCancelToken();
      final call = worker.request(
          crossGenerateRequest(workload.input,
              wantsBangla: true,
              wantsEnglish: true,
              banglaOptions:
                  const PhoneticSearchOptions(minScore: 0, maxResults: null),
              englishOptions:
                  const PhoneticSearchOptions(minScore: 0, maxResults: null)),
          cancelToken: token);
      final failed = expectLater(call, throwsCancelled);
      await wait(30);
      token.cancel();
      await failed;

      final stopwatch = Stopwatch()..start();
      await worker.request(crossGenerateRequest('Masud',
          wantsBangla: true,
          wantsEnglish: false,
          banglaOptions: const PhoneticSearchOptions(),
          englishOptions: const PhoneticSearchOptions()));
      expect(
          stopwatch.elapsedMilliseconds, lessThan(workload.directRunMs ~/ 3));
    });

    test('an unknown operation comes back as a worker error', () async {
      final worker = TimeSlicedWorker(config);
      addTearDown(worker.dispose);
      await expectLater(worker.request({'op': 'unknown'}),
          throwsA(isA<PhoneticWorkerException>()));
      await expectLater(worker.request({'op': 'crossGenerate', 'input': 42}),
          throwsA(isA<PhoneticWorkerException>()));
    });
  });
}
