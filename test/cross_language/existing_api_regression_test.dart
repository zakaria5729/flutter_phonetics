import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

List<(String, double)> wordsAndScores(List<PhoneticMatch> matches) => [
      for (final match in matches) (match.word, match.score),
    ];

void main() {
  final banglaEngine = PhoneticEngine(language: banglaLanguage);
  final englishEngine = PhoneticEngine(language: englishLanguage);

  test('Bangla Masud at 90 keeps its documented output', () {
    final result = banglaEngine.generate('মাসুদ', minScore: 90);
    expect(result.error, isNull);
    expect(wordsAndScores(result.matches), [
      ('মাসুদ', 100),
      ('মাসূদ', 97),
      ('মাশুদ', 95),
      ('মাষুদ', 95),
      ('মাশূদ', 92.15),
      ('মাষূদ', 92.15),
    ]);
    expect(result.matches[1].changes.single.position, 3);
    expect(result.matches[1].changes.single.to, '\u09C2');
  });

  test('English Philip at 90 keeps its documented output', () {
    final result = englishEngine.generate('Philip', minScore: 90);
    expect(result.error, isNull);
    expect(wordsAndScores(result.matches).take(6), [
      ('Philip', 100),
      ('Filip', 95),
      ('Phillip', 95),
      ('Philipp', 95),
      ('Fillip', 90.25),
      ('Phillipp', 90.25),
    ]);
  });

  test('existing similarity, matching and ranking are unchanged', () {
    expect(banglaEngine.similarity('আসাদ', 'আছাদ').score, 85);
    expect(banglaEngine.matches('আসাদ', 'আচাদ').isMatch, isFalse);
    expect(banglaEngine.matches('আসাদ', 'আছাদ').isMatch, isTrue);
    expect(englishEngine.similarity('Philip', 'Filip').score, 95);
    final ranked =
        banglaEngine.rank('আসাদ', ['করিম', 'আছাদ', 'আশাদ'], minScore: 80);
    expect(ranked.matches,
        const [PhoneticMatch('আশাদ', 95), PhoneticMatch('আছাদ', 85)]);
  });

  test('existing facades give the same results as before', () async {
    final bangla = BanglaPhonetics();
    final english = EnglishPhonetics();
    addTearDown(bangla.dispose);
    addTearDown(english.dispose);
    expect((await bangla.generateWords('আসাদ', minScore: 90)).words,
        ['আসাদ', 'আশাদ', 'আষাদ']);
    expect(
        wordsAndScores(
            (await english.generate('Philip', minScore: 90)).matches),
        wordsAndScores(englishEngine.generate('Philip', minScore: 90).matches));
  });

  test('same-script lists use the same words, scores and changes', () {
    for (final name in ['রহিম', 'মোহাম্মদ', 'জাহাঙ্গীর']) {
      final fromCrossLanguage = CrossLanguageEngine().generate(name,
          languages: {banglaLanguage}, maxResults: 120, minScore: 0);
      final existing =
          banglaEngine.generate(name, maxResults: 120, minScore: 0);
      expect(fromCrossLanguage.bangla.matches, existing.matches);
      expect(
          [for (final match in fromCrossLanguage.bangla.matches) match.changes],
          [for (final match in existing.matches) match.changes]);
    }
  });
}
