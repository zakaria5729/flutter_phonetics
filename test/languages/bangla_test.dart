import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

void main() {
  final engine = PhoneticEngine(language: banglaLanguage);

  List<PhoneticMatch> generate(String input,
          {double minScore = 0,
          int maxResults = 100,
          bool includeOriginal = true,
          int? maxChanges}) =>
      engine
          .generate(input,
              minScore: minScore,
              maxResults: maxResults,
              includeOriginal: includeOriginal,
              maxChanges: maxChanges)
          .matches;

  List<String> generateWords(String input,
          {double minScore = 0, int? maxResults = 100, int? maxChanges}) =>
      engine
          .generateWords(input,
              minScore: minScore,
              maxResults: maxResults,
              maxChanges: maxChanges)
          .words;

  double similarity(String a, String b) => engine.similarity(a, b).score;

  group('generate', () {
    test('আসাদ at 90% and above', () {
      final matches = generate('আসাদ', minScore: 90);
      expect(
          [for (final match in matches) match.word], ['আসাদ', 'আশাদ', 'আষাদ']);
      expect([for (final match in matches) match.score], [100, 95, 95]);
    });

    test('lower thresholds add the weaker sound-alikes', () {
      expect(generateWords('আসাদ', minScore: 80),
          containsAll(['আসাদ', 'আশাদ', 'আষাদ', 'আছাদ']));
      expect(
          generateWords('আসাদ', minScore: 75),
          containsAll(
              ['আসাদ', 'আশাদ', 'আষাদ', 'আছাদ', 'আসাড', 'আচাদ', 'আসাধ']));
      expect(generateWords('আসাদ', minScore: 90), isNot(contains('আছাদ')));
    });

    test('sorted best first, within minScore, without duplicates', () {
      final matches = generate('শরীফ', minScore: 60, maxResults: 500);
      for (var i = 1; i < matches.length; i++) {
        expect(matches[i - 1].score, greaterThanOrEqualTo(matches[i].score));
      }
      expect(matches.every((match) => match.score >= 60), isTrue);
      final words = [for (final match in matches) match.word];
      expect(words.toSet().length, words.length);
    });

    test('a very large maxResults still returns every variant', () {
      final everything = generateWords('আসাদ', minScore: 75, maxResults: null);
      expect(generateWords('আসাদ', minScore: 75, maxResults: 4503599627370496),
          everything);
      expect(
          everything,
          containsAll(
              ['আসাদ', 'আশাদ', 'আষাদ', 'আছাদ', 'আসাড', 'আচাদ', 'আসাধ']));
    });

    test('includeOriginal: false drops the input', () {
      final words = generate('আসাদ', minScore: 90, includeOriginal: false)
          .map((m) => m.word);
      expect(words, ['আশাদ', 'আষাদ']);
    });

    test('maxResults and maxChanges', () {
      expect(generate('আসাদ', maxResults: 3).length, 3);
      final singleChange = generate('আসাদ', minScore: 0, maxChanges: 1);
      expect(singleChange.every((match) => match.changes.length <= 1), isTrue);
      expect(singleChange.map((match) => match.word),
          containsAll(['আশাদ', 'আষাদ', 'আছাদ', 'আসাড', 'আচাদ', 'আসাধ']));
      expect(generateWords('আসাদ', maxChanges: 0), ['আসাদ']);
    });

    test('changes describe the swaps', () {
      final variant =
          generate('আসাদ').firstWhere((match) => match.word == 'আশাদ');
      expect(
          variant.changes.single,
          const PhoneticChange(
              position: 1, from: 'স', to: 'শ', similarity: 0.95));
    });

    test('conjuncts and vowel signs', () {
      expect(generate('ক্ষমা'), contains(const PhoneticMatch('খমা', 90)));
      expect(generate('কৃষক'), contains(const PhoneticMatch('ক্রিষক', 95)));
      expect(
          generate('মোহাম্মদ'), contains(const PhoneticMatch('মুহাম্মদ', 80)));
    });

    test('a word without generating rules returns only itself', () {
      expect(generateWords('মামা'), ['মামা']);
    });

    test('blank input returns nothing', () {
      expect(generate('   '), isEmpty);
    });
  });

  group('similarity', () {
    test('agrees with generate scores', () {
      expect(similarity('আসাদ', 'আসাদ'), 100);
      expect(similarity('আসাদ', 'আশাদ'), 95);
      expect(similarity('আসাদ', 'আছাদ'), 85);
      expect(similarity('আসাদ', 'আচাদ'), 75);
      expect(similarity('ক্ষমা', 'খমা'), 90);
      expect(similarity('বাড়ি', 'বাড়ী'), 97);
      expect(similarity('বাড়ি', 'বারি'), 85);
      expect(similarity('মোহাম্মদ', 'মুহাম্মদ'), 80);
    });

    test('unrelated words score low', () {
      expect(similarity('আসাদ', 'আসাম'), 40);
      expect(similarity('আসাদ', 'করিম'), lessThan(10));
      expect(similarity('আসাদ', 'আসসাদ'), 50);
    });

    test('is never below the generated score', () {
      for (final word in ['আসাদ', 'শরীফ', 'রহিম', 'নাজনীন', 'বাড়ি', 'কৃষক']) {
        for (final match in generate(word, maxResults: 60)) {
          expect(similarity(word, match.word),
              greaterThanOrEqualTo(match.score - 0.01),
              reason: '$word → ${match.word}');
        }
      }
    });

    test('treats different Unicode encodings as the same text', () {
      final withNukta =
          String.fromCharCodes([0x09AC, 0x09BE, 0x09A1, 0x09BC, 0x09BF]);
      final precomposed =
          String.fromCharCodes([0x09AC, 0x09BE, 0x09DC, 0x09BF]);
      expect(similarity(withNukta, precomposed), 100);
    });

    test('matches()', () {
      expect(engine.matches('আসাদ', 'আছাদ').isMatch, isTrue);
      expect(engine.matches('আসাদ', 'আচাদ').isMatch, isFalse);
      expect(engine.matches('আসাদ', 'আচাদ', minScore: 70).isMatch, isTrue);
    });
  });

  group('rank', () {
    const names = ['করিম', 'আছাদ', 'আশাদ', 'আসাদ', 'আসাদ', 'আচাদ', 'রহিম'];

    test('filters, sorts and removes duplicates', () {
      expect(engine.rank('আসাদ', names, minScore: 80).matches, const [
        PhoneticMatch('আসাদ', 100),
        PhoneticMatch('আশাদ', 95),
        PhoneticMatch('আছাদ', 85),
      ]);
    });

    test('limit keeps the best', () {
      expect([
        for (final match in engine.rank('আসাদ', names, limit: 2).matches)
          match.word
      ], [
        'আসাদ',
        'আশাদ'
      ]);
    });

    test('early exit gives the same answer as scoring everything', () {
      final candidates = [
        for (final word in ['আসাদ', 'শরীফ', 'রহিম', 'নাজনীন', 'কৃষক'])
          ...generateWords(word, maxResults: 40),
        'করিম',
        'জামাল',
        'রাশেদ',
        'ফাতেমা',
      ];
      for (final query in ['আসাদ', 'নাজনিন', 'ক্রিষক']) {
        final everything = [
          for (final candidate in candidates.toSet())
            if (similarity(query, candidate) >= 70)
              PhoneticMatch(candidate, similarity(query, candidate)),
        ]..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            return byScore != 0 ? byScore : a.word.compareTo(b.word);
          });
        expect(engine.rank(query, candidates, minScore: 70).matches, everything,
            reason: query);
        expect(engine.rank(query, candidates, minScore: 70, limit: 5).matches,
            everything.take(5).toList(),
            reason: '$query with limit');
      }
    });
  });

  test('custom rules extend the defaults', () {
    final custom = PhoneticEngine(
      language: banglaLanguage,
      rules: banglaLanguage.defaultRuleSet.extend([
        const PhoneticRule(['ম', 'ন'], 0.6)
      ]),
    );
    expect(custom.error, isNull);
    expect(custom.generate('আসাম', minScore: 0).matches,
        contains(const PhoneticMatch('আসান', 60)));
    expect(custom.generate('আসাম', minScore: 0).matches,
        contains(const PhoneticMatch('আশাম', 95)));
  });

  group('optional final ো, nasal conjuncts and vowel letters', () {
    test('words with and without a final ো are close', () {
      expect(similarity('অত', 'অতো'), 85);
      expect(similarity('কত', 'কতো'), 85);
      expect(generate('কত'), contains(const PhoneticMatch('কতো', 85)));
    });

    test('the final ো only counts at the end of a word', () {
      expect(similarity('অতও', 'অতোও'), lessThan(70));
    });

    test('ঞ্জ and নজ are close', () {
      expect(similarity('আঞ্জাম', 'আনজাম'), 90);
      expect(similarity('ইঞ্জেকশন', 'ইনজেকশন'), 90);
    });

    test('a vowel letter and its vowel sign are close when comparing', () {
      expect(similarity('আজও', 'আজো'), 90);
      expect(similarity('আইনই', 'আইনি'), 90);
      expect(similarity('অধিকারই', 'অধিকারী'), 90);
      expect(similarity('আনসারউল্লাহ', 'আনসারুল্লাহ'), 90);
    });

    test('rank finds them', () {
      final ranked =
          engine.rank('আজও', ['আজো', 'আজই', 'করিম'], minScore: 80).matches;
      expect(ranked.map((match) => match.word), ['আজো']);
    });

    test('vowel letters are never used to build new spellings', () {
      for (final word in ['মাসুদ', 'আজও', 'ইমরান', 'আইনই', 'ঐশী', 'ওমর']) {
        for (final match in generate(word, minScore: 0, maxResults: 500)) {
          final start = match.word.codeUnitAt(0);
          expect(start >= 0x09BE && start <= 0x09CD, isFalse,
              reason: '$word -> ${match.word} starts with a vowel sign');
          expect(match.word, isNot(contains('মআ')), reason: match.word);
        }
      }
      expect(generateWords('মাসুদ', minScore: 0, maxResults: null),
          isNot(contains('মআসুদ')));
    });

    test('scores of the older rules are unchanged', () {
      expect(similarity('মাসুদ', 'মাশুদ'), 95);
      expect(similarity('শরীফ', 'শরিফ'), 97);
      expect(similarity('রহিম', 'রহীম'), 97);
      expect(similarity('মাসুদ', 'করিম'), lessThan(2));
    });
  });
}
