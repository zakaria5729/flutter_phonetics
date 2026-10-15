import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

void main() {
  final engine = PhoneticEngine(language: banglaLanguage);
  final isArgumentError = isA<PhoneticArgumentException>();

  test('invalid arguments are returned, never thrown', () {
    expect(engine.generate('আসাদ', minScore: 120).error, isArgumentError);
    expect(
        engine.generate('আসাদ', minScore: double.nan).error, isArgumentError);
    expect(engine.generate('আসাদ', maxResults: 0).error, isArgumentError);
    expect(engine.generate('আসাদ', maxChanges: -1).error, isArgumentError);
    expect(engine.generateWords('আসাদ', maxResults: 0).error, isArgumentError);
    expect(
        engine.matches('আসাদ', 'আছাদ', minScore: 101).error, isArgumentError);
    expect(engine.rank('আসাদ', ['আছাদ'], limit: 0).error, isArgumentError);
    expect(engine.rank('আসাদ', ['আছাদ'], minScore: -1).error, isArgumentError);
    expect(engine.generate('আসাদ', maxResults: 0).matches, isEmpty);
  });

  test('a candidate list that throws while being read', () {
    Iterable<String> candidates() sync* {
      yield 'আসাদ';
      throw StateError('cannot read');
    }

    final (:matches, :error) = engine.rank('আসাদ', candidates());
    expect(error, isArgumentError);
    expect(matches, isEmpty);
  });

  test('invalid settings are reported by every call', () {
    final broken = PhoneticEngine(language: banglaLanguage, gapSimilarity: 2);
    expect(broken.error, isArgumentError);
    expect(broken.error!.message, contains('gapSimilarity'));
    expect(broken.generate('আসাদ').error, isArgumentError);
    expect(broken.generateWords('আসাদ').error, isArgumentError);
    expect(broken.similarity('আসাদ', 'আছাদ').error, isArgumentError);
    expect(broken.matches('আসাদ', 'আছাদ').error, isArgumentError);
    expect(broken.rank('আসাদ', ['আছাদ']).error, isArgumentError);
  });

  test('every setting is checked and all problems are listed', () {
    final broken = PhoneticEngine(
        language: banglaLanguage,
        gapSimilarity: 0,
        markGapSimilarity: 1,
        unrelatedSimilarity: double.nan);
    final message = broken.error!.message;
    expect(message, contains('gapSimilarity'));
    expect(message, contains('markGapSimilarity'));
    expect(message, contains('unrelatedSimilarity'));
  });

  test('a rule set with problems makes the engine report them', () {
    final rules = PhoneticRuleSet([
      const PhoneticRule(['ক'], 0.5)
    ], language: banglaLanguage);
    final withBadRules = PhoneticEngine(language: banglaLanguage, rules: rules);
    expect(withBadRules.error, isArgumentError);
    expect(withBadRules.generate('আসাদ').error, isArgumentError);
  });

  test('rules from another language are rejected', () {
    final mixed = PhoneticEngine(
        language: englishLanguage, rules: banglaLanguage.defaultRuleSet);
    expect(mixed.error, isArgumentError);
    expect(mixed.error!.message, contains('"bn"'));
    expect(mixed.error!.message, contains('"en"'));
    expect(mixed.generate('asad').error, isArgumentError);
  });

  test('an invalid language is reported', () {
    final language =
        PhoneticLanguage(code: '', name: 'Nameless', rules: const []);
    expect(language.error, isArgumentError);
    final engineWithBadLanguage = PhoneticEngine(language: language);
    expect(engineWithBadLanguage.error, isArgumentError);
    expect(engineWithBadLanguage.similarity('a', 'b').error, isArgumentError);
  });

  test('a language definition that cannot be read is reported', () {
    for (final garbage in [
      null,
      'text',
      5,
      <Object?>[],
      {'code': 7}
    ]) {
      expect(PhoneticLanguage.fromJson(garbage).error, isArgumentError,
          reason: '$garbage');
    }
    final languageWithBadSequences = PhoneticLanguage.fromJson({
      'code': 'xx',
      'name': 'Test',
      'foldCase': true,
      'sequences': [
        ['a'],
        'junk'
      ],
      'marks': ['x'],
    });
    expect(languageWithBadSequences.error!.message, contains('sequence'));
    expect(languageWithBadSequences.error!.message, contains('mark'));
  });

  group('output is bounded', () {
    test('unlimited results on a long input stay small and best first', () {
      final english = PhoneticEngine(language: englishLanguage);
      final input = 'Asad ' * 300;
      final stopwatch = Stopwatch()..start();
      final (:matches, :error) =
          english.generate(input, minScore: 0, maxResults: null, maxChanges: 2);

      expect(error, isNull);
      expect(matches, isNotEmpty);
      expect(matches.length, lessThanOrEqualTo(20000000 ~/ input.length));
      expect(matches.first.score, 100);
      for (var i = 1; i < matches.length; i++) {
        expect(matches[i - 1].score, greaterThanOrEqualTo(matches[i].score));
      }
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 20)));
    });

    test('a huge explicit maxResults is capped the same way', () {
      final english = PhoneticEngine(language: englishLanguage);
      final matches = english
          .generate('Catherine Christopher Elizabeth',
              minScore: 0, maxResults: 4503599627370496)
          .matches;
      expect(matches.length, lessThanOrEqualTo(100000));
      expect(matches.first.score, 100);
    });

    test('short names are not affected by the ceiling', () {
      final english = PhoneticEngine(language: englishLanguage);
      expect(
          english
              .generate('christopher', minScore: 0, maxResults: null)
              .matches
              .length,
          8100);
    });
  });
}
