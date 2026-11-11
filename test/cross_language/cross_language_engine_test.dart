import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

import '../support/cross_language_support.dart';

List<String> wordsOf(PhoneticMatchesResult side) => [
      for (final match in side.matches) match.word,
    ];

void main() {
  final banglaEngine = PhoneticEngine(language: banglaLanguage);
  final englishEngine = PhoneticEngine(language: englishLanguage);

  group('Bangla input', () {
    test('the Bangla list equals the existing Bangla engine output', () {
      for (final name in ['মাসুদ', 'রহিম', 'ফারজানা', 'মোহাম্মদ আব্দুল']) {
        for (final maxChanges in [null, 1, 2]) {
          final result = crossLanguageEngine.generate(name,
              languages: bothLanguages, minScore: 80, maxChanges: maxChanges);
          final existing =
              banglaEngine.generate(name, minScore: 80, maxChanges: maxChanges);
          expect(result.bangla.matches, existing.matches, reason: name);
          expect([for (final match in result.bangla.matches) match.changes],
              [for (final match in existing.matches) match.changes]);
          expect(result.bangla.error, isNull);
          expect(result.english.matches, isNotEmpty);
        }
      }
    });

    test('the documented Masud output is reproduced', () {
      final result = crossLanguageEngine.generate('মাসুদ',
          languages: bothLanguages, minScore: 90);
      expect([
        for (final match in result.bangla.matches) (match.word, match.score)
      ], [
        ('মাসুদ', 100),
        ('মাসূদ', 97),
        ('মাশুদ', 95),
        ('মাষুদ', 95),
        ('মাশূদ', 92.15),
        ('মাষূদ', 92.15),
      ]);
      expect([
        for (final match in result.english.matches) (match.word, match.score)
      ], [
        ('Masud', 100),
        ('Masood', 95),
        ('Masoud', 90),
        ('Mashud', 90)
      ]);
    });

    test('includeOriginal concerns only the Bangla list', () {
      final result = crossLanguageEngine.generate('মাসুদ',
          languages: bothLanguages, minScore: 90, includeOriginal: false);
      expect(wordsOf(result.bangla), isNot(contains('মাসুদ')));
      expect(wordsOf(result.english).first, 'Masud');
      expect(result.english.matches.first.score, 100);
    });

    test('maxChanges applies to both lists', () {
      final result = crossLanguageEngine.generate('মাসুদ',
          languages: bothLanguages, minScore: 0, maxChanges: 0);
      expect(wordsOf(result.bangla), ['মাসুদ']);
      expect(wordsOf(result.english), ['Masud']);
    });

    test('an emoji inside a Bangla name fails only the English list', () {
      final result =
          crossLanguageEngine.generate('মাসুদ😀', languages: bothLanguages);
      expect(result.english.error, isA<PhoneticArgumentException>());
      expect(result.bangla.error, isNull);
      expect(result.bangla.matches, isNotEmpty);
      expect(result.error, same(result.english.error));
    });

    test('zero length slots keep a stable order', () {
      final words = englishWords('ফারজানা');
      expect(words, containsAll(['Farjana', 'Farajana', 'Farazana']));
    });
  });

  group('both directions', () {
    test('Bangla only and English only leave the other list empty', () {
      final banglaRequest =
          crossLanguageEngine.generate('Masud', languages: banglaOnly);
      expect(banglaRequest.english.matches, isEmpty);
      expect(banglaRequest.english.error, isNull);
      expect(banglaRequest.bangla.matches, isNotEmpty);

      final englishRequest =
          crossLanguageEngine.generate('Masud', languages: englishOnly);
      expect(englishRequest.bangla.matches, isEmpty);
      expect(englishRequest.bangla.error, isNull);
      expect(englishRequest.english.matches, isNotEmpty);
    });

    test('languages default to both', () {
      final result = crossLanguageEngine.generate('Masud');
      expect(result.bangla.matches, isNotEmpty);
      expect(result.english.matches, isNotEmpty);
      expect(result.forLanguage(banglaLanguage), same(result.bangla));
      expect(result.forLanguage(englishLanguage), same(result.english));
      expect(
          result.forLanguage(
              PhoneticLanguage(code: 'fr', name: 'French', rules: const [])),
          isNull);
    });

    test('options of each language are independent', () {
      final result = crossLanguageEngine.generate(
        'মাসুদ',
        languages: bothLanguages,
        banglaOptions: const PhoneticSearchOptions(minScore: 99, maxResults: 5),
        englishOptions:
            const PhoneticSearchOptions(minScore: 85, maxResults: 3),
      );
      expect(wordsOf(result.bangla), ['মাসুদ']);
      expect(wordsOf(result.english), ['Masud', 'Masood', 'Masoud']);
    });

    test('minScore and maxResults apply to each list on its own', () {
      final result = crossLanguageEngine.generate('Masud',
          languages: bothLanguages, minScore: 0, maxResults: 4);
      expect(result.bangla.matches.length, 4);
      expect(result.english.matches.length, 4);
    });

    test('results are identical on repeated runs', () {
      for (final name in ['Masud', 'মাসুদ', 'Abdul Karim']) {
        final first = crossLanguageEngine.generate(name, minScore: 50);
        final second = crossLanguageEngine.generate(name, minScore: 50);
        expect(first.bangla.matches, second.bangla.matches);
        expect(first.english.matches, second.english.matches);
      }
    });

    test('only the reference reading scores one hundred', () {
      final result = crossLanguageEngine.generate('Masud', minScore: 40);
      for (final side in [result.bangla, result.english]) {
        expect(side.matches.first.score, 100);
        expect(
            side.matches.skip(1).every((match) => match.score < 100), isTrue);
        expect(side.matches.every((match) => match.score >= 40), isTrue);
      }
    });
  });

  group('errors', () {
    test('empty and blank input give empty lists without an error', () {
      for (final blank in ['', ' ', '\t\n  ']) {
        final result = crossLanguageEngine.generate(blank);
        expect(result.error, isNull);
        expect(result.bangla.matches, isEmpty);
        expect(result.english.matches, isEmpty);
      }
    });

    test('unsupported input fails both requested lists', () {
      for (final invalid in ['12345', 'مسعود', '😀']) {
        final result =
            crossLanguageEngine.generate(invalid, languages: bothLanguages);
        expect(result.bangla.error, isA<PhoneticArgumentException>(),
            reason: invalid);
        expect(result.english.error, isA<PhoneticArgumentException>(),
            reason: invalid);
        expect(result.bangla.matches, isEmpty);
        expect(result.english.matches, isEmpty);
      }
      final englishRequest =
          crossLanguageEngine.generate('12345', languages: englishOnly);
      expect(englishRequest.bangla.error, isNull);
      expect(englishRequest.english.error, isNotNull);
    });

    test('an empty language set or an unknown language is an argument error',
        () {
      final empty = crossLanguageEngine.generate('Masud', languages: {});
      expect(empty.bangla.error, isA<PhoneticArgumentException>());
      expect(empty.english.error, same(empty.bangla.error));

      final french =
          PhoneticLanguage(code: 'fr', name: 'French', rules: const []);
      final unknown = crossLanguageEngine
          .generate('Masud', languages: {banglaLanguage, french});
      expect(unknown.bangla.error, isA<PhoneticArgumentException>());
      expect(unknown.english.error, same(unknown.bangla.error));
      expect(unknown.error!.message, contains('fr'));
    });

    test('invalid options fail both lists with the same error', () {
      for (final invalid in [
        () => crossLanguageEngine.generate('Masud', minScore: 101),
        () => crossLanguageEngine.generate('Masud', minScore: double.nan),
        () => crossLanguageEngine.generate('Masud', maxResults: 0),
        () => crossLanguageEngine.generate('Masud', maxChanges: -1),
      ]) {
        final result = invalid();
        expect(result.bangla.error, isA<PhoneticArgumentException>());
        expect(result.english.error, same(result.bangla.error));
        expect(result.bangla.matches, isEmpty);
      }
    });

    test('options name the language they belong to', () {
      final result = crossLanguageEngine.generate('Masud',
          englishOptions: const PhoneticSearchOptions(minScore: -1));
      expect(result.error!.message, startsWith('English options:'));
      final bangla = crossLanguageEngine.generate('Masud',
          banglaOptions: const PhoneticSearchOptions(maxResults: 0));
      expect(bangla.error!.message, startsWith('Bangla options:'));
    });

    test('options of a language that is not requested are not checked', () {
      final result = crossLanguageEngine.generate('Masud',
          languages: englishOnly,
          banglaOptions: const PhoneticSearchOptions(minScore: 500));
      expect(result.error, isNull);
      expect(result.english.matches, isNotEmpty);
    });

    test('a broken Bangla engine setting fails only the Bangla list', () {
      final broken = CrossLanguageEngine(gapSimilarity: 2);
      expect(broken.error, isA<PhoneticArgumentException>());
      final result = broken.generate('মাসুদ');
      expect(result.bangla.error, isA<PhoneticArgumentException>());
      expect(result.bangla.matches, isEmpty);
      expect(result.english.error, isNull);
      expect(wordsOf(result.english).first, 'Masud');
    });

    test('rules for another language fail only the Bangla list', () {
      final wrongRules = PhoneticRuleSet(const [], language: englishLanguage);
      final broken = CrossLanguageEngine(banglaRules: wrongRules);
      final result = broken.generate('মাসুদ');
      expect(result.bangla.error, isA<PhoneticArgumentException>());
      expect(result.english.error, isNull);
      expect(result.english.matches, isNotEmpty);
    });

    test('custom Bangla rules shape the Bangla list', () {
      final custom = CrossLanguageEngine(
        banglaRules: banglaLanguage.defaultRuleSet.extend([
          const PhoneticRule(['ম', 'ন'], 0.6)
        ]),
      );
      final result =
          custom.generate('আসাম', minScore: 0, languages: banglaOnly);
      expect(result.bangla.matches, contains(const PhoneticMatch('আসান', 60)));
    });
  });

  group('input forms', () {
    test('a very long input stays bounded by maxResults', () {
      final longName = List.filled(30, 'Abdul Rahman').join(' ');
      final result =
          crossLanguageEngine.generate(longName, minScore: 0, maxResults: 150);
      expect(result.bangla.matches.length, lessThanOrEqualTo(150));
      expect(result.english.matches.length, lessThanOrEqualTo(150));
      expect(result.bangla.matches, isNotEmpty);
    });

    test('the same-script list of English input equals the existing engine',
        () {
      for (final name in ['Philip', 'Masud', 'Abdul Karim']) {
        final result = crossLanguageEngine.generate(name,
            languages: bothLanguages, minScore: 85, maxChanges: 1);
        final existing =
            englishEngine.generate(name, minScore: 85, maxChanges: 1);
        expect(result.english.matches, existing.matches);
      }
    });
  });
}
