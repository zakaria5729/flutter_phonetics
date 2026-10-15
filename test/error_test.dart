/// Author: Zakaria Hossain
/// Description: Tests covering parameter validation errors and exceptional conditions.
library;

import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/protocol/protocol.dart';
import 'package:flutter_phonetics/src/worker/time_sliced_worker.dart';
import 'package:test/test.dart';

final isArgumentError = isA<PhoneticArgumentException>();

Iterable<String> throwingCandidates() sync* {
  yield 'আসাদ';
  throw StateError('cannot read candidates');
}

void main() {
  late BanglaPhonetics phonetics;

  setUp(() => phonetics = BanglaPhonetics());
  tearDown(() => phonetics.dispose());

  group('invalid arguments', () {
    test('generate', () async {
      for (final call in [
        phonetics.generate('আসাদ', minScore: -1),
        phonetics.generate('আসাদ', minScore: 101),
        phonetics.generate('আসাদ', minScore: double.nan),
        phonetics.generate('আসাদ', maxResults: 0),
        phonetics.generate('আসাদ', maxChanges: -1),
      ]) {
        final (:matches, :error) = await call;
        expect(error, isArgumentError);
        expect(matches, isEmpty);
      }
    });

    test('generateWords, matches and rank', () async {
      final words = await phonetics.generateWords('আসাদ', maxResults: 0);
      expect(words.error, isArgumentError);
      expect(words.words, isEmpty);

      final check = await phonetics.matches('আসাদ', 'আছাদ', minScore: 500);
      expect(check.error, isArgumentError);
      expect(check.isMatch, isFalse);

      expect((await phonetics.rank('আসাদ', ['আছাদ'], limit: 0)).error,
          isArgumentError);
      expect((await phonetics.rank('আসাদ', ['আছাদ'], minScore: -5)).error,
          isArgumentError);
    });

    test('the message names the argument', () async {
      final (:matches, :error) =
          await phonetics.generate('আসাদ', maxResults: 0);
      expect(error!.message, contains('maxResults'));
    });

    test('a candidate list that throws while being read', () async {
      final (:matches, :error) =
          await phonetics.rank('আসাদ', throwingCandidates());
      expect(error, isArgumentError);
      expect(matches, isEmpty);
    });

    test('the instance keeps working afterwards', () async {
      await phonetics.generate('আসাদ', maxResults: 0);
      expect((await phonetics.generateWords('আসাদ', minScore: 90)).words,
          ['আসাদ', 'আশাদ', 'আষাদ']);
    });
  });

  group('invalid settings', () {
    test('the constructor does not throw and every call reports the problem',
        () async {
      final broken = BanglaPhonetics(gapSimilarity: 2);
      expect(broken.workerName, 'unavailable');

      expect((await broken.generate('আসাদ')).error, isArgumentError);
      expect((await broken.generateWords('আসাদ')).error, isArgumentError);
      expect((await broken.similarity('আসাদ', 'আছাদ')).error, isArgumentError);
      expect((await broken.matches('আসাদ', 'আছাদ')).error, isArgumentError);
      expect((await broken.rank('আসাদ', ['আছাদ'])).error, isArgumentError);

      broken.cancelAll();
      await broken.dispose();
    });

    test('rules with problems are reported by every call', () async {
      final broken = BanglaPhonetics(
          rules: PhoneticRuleSet([
        const PhoneticRule(['ক'], 0.5)
      ], language: banglaLanguage));
      expect(broken.workerName, 'unavailable');
      final (:matches, :error) = await broken.generate('আসাদ');
      expect(error, isArgumentError);
      expect(error!.message, contains('rule'));
      expect(matches, isEmpty);
      expect((await broken.rank('আসাদ', ['আছাদ'])).error, isArgumentError);
    });

    test('every setting is checked', () async {
      expect(
          (await BanglaPhonetics(markGapSimilarity: 0).generate('আসাদ')).error,
          isArgumentError);
      expect(
          (await BanglaPhonetics(unrelatedSimilarity: double.nan)
                  .generate('আসাদ'))
              .error,
          isArgumentError);
    });
  });

  group('after dispose', () {
    test('every call returns a disposed error', () async {
      final disposable = BanglaPhonetics();
      await disposable.dispose();
      await disposable.dispose();

      final isDisposed = isA<PhoneticDisposedException>();
      expect((await disposable.generate('আসাদ')).error, isDisposed);
      expect((await disposable.generateWords('আসাদ')).error, isDisposed);
      expect((await disposable.similarity('আসাদ', 'আছাদ')).error, isDisposed);
      expect((await disposable.matches('আসাদ', 'আছাদ')).error, isDisposed);
      expect((await disposable.rank('আসাদ', ['আছাদ'])).error, isDisposed);
      disposable.cancelAll();
    });
  });

  group('worker failures', () {
    test('an unknown operation comes back as a worker error', () async {
      final worker = TimeSlicedWorker(
          encodeEngineConfig(PhoneticEngine(language: banglaLanguage)));
      addTearDown(worker.dispose);
      await expectLater(worker.request({'op': 'unknown'}),
          throwsA(isA<PhoneticWorkerException>()));
      final similarity =
          await worker.request(similarityRequest('আসাদ', 'আছাদ'));
      expect(decodeSimilarity(similarity), 85);
    });

    test('malformed arguments inside a request come back as a worker error',
        () async {
      final worker = TimeSlicedWorker(
          encodeEngineConfig(PhoneticEngine(language: banglaLanguage)));
      addTearDown(worker.dispose);
      await expectLater(worker.request({'op': 'generate', 'input': 42}),
          throwsA(isA<PhoneticWorkerException>()));
    });
  });

  test('cancelAll with nothing pending does nothing', () {
    phonetics.cancelAll();
    phonetics.cancelAll();
  });

  test('cancelling a token twice or after use does nothing', () async {
    final token = PhoneticCancelToken();
    await phonetics.generate('আসাদ', cancelToken: token);
    token.cancel();
    token.cancel();
    expect((await phonetics.generate('আসাদ', cancelToken: token)).error,
        isA<PhoneticCancelledException>());
  });
}
