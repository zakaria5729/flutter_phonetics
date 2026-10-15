import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

void main() {
  final isArgumentError = isA<PhoneticArgumentException>();

  PhoneticRuleSet bangla(List<PhoneticRule> rules) =>
      PhoneticRuleSet(rules, language: banglaLanguage);

  test('default rule sets are built once per language', () {
    expect(
        identical(banglaLanguage.defaultRuleSet, banglaLanguage.defaultRuleSet),
        isTrue);
    expect(banglaLanguage.defaultRuleSet.error, isNull);
    expect(englishLanguage.defaultRuleSet.error, isNull);
    expect(englishLanguage.defaultRuleSet.languageCode, 'en');
  });

  test('extend adds rules and keeps the language', () {
    final extended = banglaLanguage.defaultRuleSet.extend([
      const PhoneticRule(['ম', 'ন'], 0.6)
    ]);
    expect(extended.error, isNull);
    expect(extended.hasRuleFor('ম'), isTrue);
    expect(extended.languageCode, 'bn');
  });

  test('invalid rules are skipped and reported', () {
    final rules = bangla([
      const PhoneticRule(['ক', 'খ'], 1.5),
      const PhoneticRule(['ক'], 0.5),
      const PhoneticRule(['', 'খ'], 0.5),
      const PhoneticRule(['ম', 'ন'], 0.6),
    ]);
    expect(rules.error, isArgumentError);
    expect(rules.rules.length, 1);
    expect(rules.hasRuleFor('ম'), isTrue);
    expect(rules.hasRuleFor('ক'), isFalse);
    expect(rules.error!.message, contains('1.5'));
  });

  test('extending keeps earlier problems', () {
    final bad = bangla([
      const PhoneticRule(['ক'], 0.5)
    ]);
    final extended = bad.extend([
      const PhoneticRule(['ম', 'ন'], 0.6)
    ]);
    expect(extended.error, isArgumentError);
    expect(extended.hasRuleFor('ম'), isTrue);
    expect(banglaLanguage.defaultRuleSet.extend(const []).error, isNull);
  });

  group('JSON', () {
    test('round trip keeps rules and positions', () {
      final original = englishLanguage.defaultRuleSet;
      final copy = PhoneticRuleSet.fromJson(original.toJson(),
          language: englishLanguage);
      expect(copy.error, isNull);
      expect(copy.toJson(), original.toJson());
    });

    test('malformed data is reported, valid parts are kept', () {
      for (final garbage in [
        null,
        'text',
        42,
        [1, 2, 3],
        [
          ['x']
        ],
        [
          [0.5, 0, 0]
        ],
        [
          [0.5, 9, 0, 'ক', 'খ']
        ],
        [
          [0.5, 0, 0, 'ক', 7]
        ],
      ]) {
        expect(
            PhoneticRuleSet.fromJson(garbage, language: banglaLanguage).error,
            isArgumentError,
            reason: '$garbage');
      }
      final partlyValid = PhoneticRuleSet.fromJson([
        [0.9, 0, 0, 'ক', 'খ'],
        'junk'
      ], language: banglaLanguage);
      expect(partlyValid.error, isArgumentError);
      expect(partlyValid.hasRuleFor('ক'), isTrue);
    });
  });

  group('positions', () {
    final rules = PhoneticRuleSet([
      const PhoneticRule(['kn', 'n'], 0.9, position: RulePosition.wordStart),
      const PhoneticRule(['ah', 'a'], 0.9, position: RulePosition.wordEnd),
      const PhoneticRule(['ss', 's'], 0.9, position: RulePosition.notWordStart),
      const PhoneticRule(['q', 'k'], 0.8),
    ], language: englishLanguage);

    List<String> options(String spelling,
            {bool start = false, bool end = false}) =>
        [
          for (final alternative in rules.alternativesFor(spelling,
              atWordStart: start, atWordEnd: end))
            alternative.text,
        ];

    test('wordStart', () {
      expect(options('n', start: true), ['kn']);
      expect(options('n'), isEmpty);
    });

    test('wordEnd', () {
      expect(options('a', end: true), ['ah']);
      expect(options('a'), isEmpty);
    });

    test('notWordStart', () {
      expect(options('s'), ['ss']);
      expect(options('s', start: true), isEmpty);
    });

    test('anywhere', () {
      for (final start in [false, true]) {
        for (final end in [false, true]) {
          expect(options('q', start: start, end: end), ['k']);
        }
      }
    });

    test('the best similarity wins when positions overlap', () {
      final overlapping = PhoneticRuleSet([
        const PhoneticRule(['a', 'e'], 0.6),
        const PhoneticRule(['a', 'e'], 0.9, position: RulePosition.wordEnd),
      ], language: englishLanguage);
      expect(overlapping.alternativesFor('a').single.similarity, 0.6);
      expect(
          overlapping.alternativesFor('a', atWordEnd: true).single.similarity,
          0.9);
    });
  });

  group('score-only rules', () {
    final rules = PhoneticRuleSet([
      const PhoneticRule(['a', 'e'], 0.8),
      const PhoneticRule(['i', 'y'], 0.9, scoreOnly: true),
    ], language: englishLanguage);

    List<String> options(String spelling, {required bool generating}) => [
          for (final alternative
              in rules.alternativesFor(spelling, generating: generating))
            alternative.text,
        ];

    test('count when comparing but not when generating', () {
      expect(options('i', generating: false), ['y']);
      expect(options('i', generating: true), isEmpty);
      expect(options('a', generating: false), ['e']);
      expect(options('a', generating: true), ['e']);
      expect(rules.hasRuleFor('i'), isTrue);
    });

    test('survive extend and a round trip through plain data', () {
      final extended = rules.extend([
        const PhoneticRule(['o', 'u'], 0.7)
      ]);
      expect(options('i', generating: true), isEmpty);
      expect(extended.alternativesFor('i').single.text, 'y');
      expect(extended.alternativesFor('i', generating: true), isEmpty);
      final copy = PhoneticRuleSet.fromJson(extended.toJson(),
          language: englishLanguage);
      expect(copy.error, isNull);
      expect(copy.alternativesFor('i').single.text, 'y');
      expect(copy.alternativesFor('i', generating: true), isEmpty);
    });

    test('are used by the engine only for scoring', () {
      final engine = PhoneticEngine(language: englishLanguage, rules: rules);
      expect(engine.similarity('big', 'byg').score, 90);
      expect(engine.generate('big', minScore: 0).matches.map((m) => m.word),
          ['big']);
      expect(engine.generate('bag', minScore: 0).matches.map((m) => m.word),
          containsAll(['bag', 'beg']));
    });
  });
}
