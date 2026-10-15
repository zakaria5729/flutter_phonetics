import 'dart:math' as math;

import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/core/word_boundary.dart';
import 'package:test/test.dart';

Map<String, double> enumerateAllVariants(
    PhoneticLanguage language, PhoneticRuleSet rules, String input,
    {int maxChanges = 1 << 30}) {
  final text = language.normalize(input);
  final segments = <List<(String, double)>>[];
  var index = 0;
  while (index < text.length) {
    var length = 1;
    var alternatives = const <PhoneticAlternative>[];
    for (var candidateLength =
            math.min(rules.longestSpellingLength, text.length - index);
        candidateLength >= 1;
        candidateLength--) {
      final options = rules.alternativesFor(
        text.substring(index, index + candidateLength),
        atWordStart: startsWord(text, index),
        atWordEnd: endsWord(text, index + candidateLength),
        generating: true,
      );
      if (options.isNotEmpty) {
        length = candidateLength;
        alternatives = options;
        break;
      }
    }
    segments.add([
      (text.substring(index, index + length), 1.0),
      for (final alternative in alternatives)
        (alternative.text, alternative.similarity),
    ]);
    index += length;
  }

  final bestScores = <String, double>{};
  void extend(int segmentIndex, String prefix, double score, int changes) {
    if (changes > maxChanges) return;
    if (segmentIndex == segments.length) {
      final percent = (score * 10000).roundToDouble() / 100;
      if (percent > (bestScores[prefix] ?? -1)) bestScores[prefix] = percent;
      return;
    }
    final options = segments[segmentIndex];
    for (var option = 0; option < options.length; option++) {
      extend(segmentIndex + 1, prefix + options[option].$1,
          score * options[option].$2, changes + (option == 0 ? 0 : 1));
    }
  }

  extend(0, '', 1, 0);
  return bestScores;
}

void expectSameVariants(
    List<PhoneticMatch> actual, Map<String, double> expected, String reason) {
  expect({for (final match in actual) match.word}, expected.keys.toSet(),
      reason: reason);
  for (final match in actual) {
    expect(match.score, closeTo(expected[match.word]!, 0.011),
        reason: '$reason: ${match.word}');
  }
}

void checkLanguage(PhoneticLanguage language, List<String> inputs) {
  final engine = PhoneticEngine(language: language);

  for (final input in inputs) {
    test('${language.code}: matches full enumeration for $input', () {
      final expected = enumerateAllVariants(language, engine.rules, input);
      final matches =
          engine.generate(input, minScore: 0, maxResults: null).matches;
      expectSameVariants(matches, expected, 'all variants');
      for (var i = 1; i < matches.length; i++) {
        expect(matches[i - 1].score, greaterThanOrEqualTo(matches[i].score));
      }

      for (final minScore in [95.0, 85.0, 70.0, 50.0]) {
        final filtered = {
          for (final entry in expected.entries)
            if (entry.value >= minScore) entry.key: entry.value,
        };
        final atLeast = engine
            .generate(input, minScore: minScore, maxResults: 100000)
            .matches;
        expectSameVariants(atLeast, filtered, 'minScore $minScore');
      }

      for (final maxChanges in [0, 1, 2]) {
        final limited = enumerateAllVariants(language, engine.rules, input,
            maxChanges: maxChanges);
        final matchesWithLimit = engine
            .generate(input,
                minScore: 0, maxChanges: maxChanges, maxResults: null)
            .matches;
        expectSameVariants(matchesWithLimit, limited, 'maxChanges $maxChanges');
      }
    });
  }

  test('${language.code}: top results are a prefix of the full ranking', () {
    final input = inputs.last;
    final all = engine.generate(input, minScore: 0, maxResults: null).matches;
    for (final count in [1, 5, 17, 50]) {
      expect(engine.generate(input, minScore: 0, maxResults: count).matches,
          all.take(count).toList());
    }
  });
}

void main() {
  checkLanguage(banglaLanguage, [
    'আসাদ',
    'শরীফ',
    'কৃষক',
    'নাজনীন',
    'সৈয়দ',
    'মোহাম্মদ',
    'জসীম',
    'বিশ্বাস',
    'রহমান',
    'প্রজ্ঞা',
    'ঐশী',
    'ক্ষমাশীল',
  ]);
  checkLanguage(englishLanguage, [
    'asad',
    'sarah',
    'knight',
    'hussain',
    'mary ann',
    'jose',
    'wright',
    'catherine',
  ]);
}
