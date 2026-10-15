import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

void main() {
  final engine = PhoneticEngine(language: englishLanguage);

  List<PhoneticMatch> generate(String input,
          {double minScore = 0, int maxResults = 100, int? maxChanges}) =>
      engine
          .generate(input,
              minScore: minScore,
              maxResults: maxResults,
              maxChanges: maxChanges)
          .matches;

  Set<String> words(String input,
          {double minScore = 0, int maxResults = 500}) =>
      {
        for (final match
            in generate(input, minScore: minScore, maxResults: maxResults))
          match.word,
      };

  double similarity(String a, String b) => engine.similarity(a, b).score;

  group('generate', () {
    test('Asad keeps its capital letter', () {
      final matches = generate('Asad', minScore: 85);
      expect(matches.first, const PhoneticMatch('Asad', 100));
      expect(
          matches,
          containsAll(const [
            PhoneticMatch('Assad', 95),
            PhoneticMatch('Asadd', 95),
            PhoneticMatch('Asaad', 90),
            PhoneticMatch('Azad', 85),
          ]));
    });

    test('lower case, Title Case and UPPER CASE are kept', () {
      expect(words('asad', minScore: 90), containsAll(['asad', 'assad']));
      expect(words('Asad', minScore: 90), containsAll(['Asad', 'Assad']));
      expect(words('ASAD', minScore: 90), containsAll(['ASAD', 'ASSAD']));
      expect(words('Mary Ann', minScore: 90),
          containsAll(['Mary Ann', 'Marry Ann', 'Mary An']));
    });

    test('results are sorted, within minScore and unique', () {
      final matches = generate('Catherine', minScore: 70, maxResults: 300);
      for (var i = 1; i < matches.length; i++) {
        expect(matches[i - 1].score, greaterThanOrEqualTo(matches[i].score));
      }
      expect(matches.every((match) => match.score >= 70), isTrue);
      expect(matches.map((match) => match.word).toSet().length, matches.length);
      expect(words('Catherine', minScore: 80), contains('Katherine'));
    });

    test('names from other spellings', () {
      expect(words('Hussain', minScore: 80), contains('Hussein'));
      expect(words('Smith', minScore: 80), contains('Smyth'));
      expect(words('Philip', minScore: 90), contains('Filip'));
      expect(words('Knight', minScore: 85), contains('Night'));
      expect(words('Sarah', minScore: 85), contains('Sara'));
      expect(words('Aisha', minScore: 75), contains('Ayesha'));
    });

    test('accents are removed from the result', () {
      expect(generate('José').first, const PhoneticMatch('Jose', 100));
    });

    test('rules that depend on the position in the word', () {
      expect(words('Mary', minScore: 60).where((word) => word.startsWith('Mm')),
          isEmpty);
      expect(words('Asad', minScore: 60),
          isNot(anyOf(contains('Ahsad'), contains('Asahd'))));
      expect(words('Night', minScore: 85), contains('Knight'));
      expect(words('Rain', minScore: 85), contains('Wrain'));
      expect(words('Brain', minScore: 60), isNot(contains('Bwrain')));
      expect(words('Sara', minScore: 85), contains('Sarah'));
      expect(words('Sarat', minScore: 60), isNot(contains('Sarhat')));
    });

    test('maxChanges and maxResults', () {
      expect(generate('Asad', maxResults: 5).length, 5);
      expect(
          generate('Asad', maxChanges: 1)
              .every((match) => match.changes.length <= 1),
          isTrue);
      expect(words('Asad', minScore: 0).length, greaterThan(20));
    });
  });

  group('similarity', () {
    test('sound-alike names score high', () {
      expect(similarity('Catherine', 'Katherine'), 85);
      expect(similarity('Smith', 'Smyth'), 85);
      expect(similarity('Hussain', 'Hussein'), 85);
      expect(similarity('Philip', 'Filip'), 95);
      expect(similarity('Knight', 'Night'), 90);
      expect(similarity('Sara', 'Sarah'), 90);
      expect(similarity('Mohammad', 'Muhammad'), 70);
      expect(similarity('Aisha', 'Ayesha'), 80);
    });

    test('case and accents do not matter', () {
      expect(similarity('Asad', 'ASAD'), 100);
      expect(similarity('José', 'Jose'), 100);
      expect(similarity('  Mary   Ann ', 'mary ann'), 100);
    });

    test('unrelated words score low', () {
      expect(similarity('Asad', 'Zebra'), lessThan(10));
    });

    test('is symmetric for plain swaps', () {
      expect(similarity('Katherine', 'Catherine'), 85);
      expect(similarity('Night', 'Knight'), 90);
    });

    test('is never below the generated score', () {
      for (final name in [
        'Asad',
        'Catherine',
        'Hussain',
        'Mary Ann',
        'Knight'
      ]) {
        for (final match in generate(name, minScore: 60, maxResults: 80)) {
          expect(similarity(name, match.word),
              greaterThanOrEqualTo(match.score - 0.01),
              reason: '$name → ${match.word}');
        }
      }
    });
  });

  test('rank finds names by sound, ignoring case', () {
    const customers = [
      'katherine',
      'KATHRYN',
      'Kathy',
      'Catherine',
      'Michael',
      'Smyth',
    ];
    final ranked = engine.rank('Catherine', customers, minScore: 80);
    expect(ranked.matches.first, const PhoneticMatch('Catherine', 100));
    expect(ranked.matches.map((match) => match.word), contains('katherine'));
    expect(
        ranked.matches.map((match) => match.word), isNot(contains('Michael')));
  });
}
