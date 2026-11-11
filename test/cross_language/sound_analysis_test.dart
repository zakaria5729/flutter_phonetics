import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/cross_language/bangla_parser.dart';
import 'package:flutter_phonetics/src/cross_language/bangla_spelling_options.dart';
import 'package:flutter_phonetics/src/cross_language/bangla_to_english_plan.dart';
import 'package:flutter_phonetics/src/cross_language/english_spelling_options.dart';
import 'package:flutter_phonetics/src/cross_language/english_tokenizer.dart';
import 'package:flutter_phonetics/src/cross_language/inherent_vowel_rules.dart';
import 'package:flutter_phonetics/src/cross_language/input_script.dart';
import 'package:flutter_phonetics/src/cross_language/spelling_plan.dart';
import 'package:test/test.dart';

import '../support/cross_language_support.dart';

List<BanglaToken> tokensOf(String word) =>
    (parseBanglaText(banglaLanguage.normalize(word)) as ParsedBanglaText)
        .tokens;

Map<int, InherentVowelFate> fatesOf(String word) =>
    resolveInherentVowelFates(tokensOf(word));

List<String> englishUnitsOf(String word) =>
    (parseEnglishText(word) as ParsedEnglishText).units.map((unit) {
      return switch (unit) {
        ConsonantUnit(:final letters, :final isDoubled) =>
          isDoubled ? '$letters$letters' : letters,
        VowelUnit(:final letters) => letters,
        LiteralUnit(:final text) => text,
        EnglishWordBreakUnit(:final text) => text,
      };
    }).toList();

void expectValidOptions(SpellingOptions options) {
  for (final alternative in options.alternatives) {
    expect(alternative.similarity, greaterThan(0));
    expect(alternative.similarity, lessThan(1));
    expect(alternative.text, isNot(options.reference));
  }
  final similarities = [
    for (final alternative in options.alternatives) alternative.similarity,
  ];
  expect(similarities, orderedEquals(sortedDescending(similarities)));
}

void main() {
  group('Bangla syllable parsing', () {
    test('groups consonants, vowel signs and hasanta into syllables', () {
      final tokens = tokensOf('সাদ্দাম');
      expect(tokens.length, 3);
      final middle = tokens[1] as ConsonantGroupToken;
      expect(middle.consonants, ['দ', 'দ']);
      expect(middle.vowelSign, '\u09BE');
      expect(middle.isConjunct, isTrue);
      expect((tokens[2] as ConsonantGroupToken).hasInherentVowel, isTrue);
    });

    test('a trailing hasanta marks a consonant without a vowel', () {
      final group = tokensOf('ক্').single as ConsonantGroupToken;
      expect(group.endsWithHasanta, isTrue);
      expect(group.hasInherentVowel, isFalse);
    });

    test('khanda ta never takes a vowel', () {
      expect((tokensOf('জগ\u09CE')[2] as ConsonantGroupToken).endsWithHasanta,
          isTrue);
    });

    test('stray vowel signs and hasantas are ignored', () {
      expect(tokensOf('\u09BE'), isEmpty);
      expect(tokensOf('মাসুদ্').length, 3);
    });

    test('zero width joiners and stray nukta never swallow a vowel sign', () {
      final withZeroWidthNonJoiner = tokensOf('র\u200C\u09BFহিম');
      expect((withZeroWidthNonJoiner.first as ConsonantGroupToken).vowelSign,
          '\u09BF');
    });

    test('unsupported characters are rejected with their position', () {
      final outcome = parseBanglaText('মাসুদ😀');
      expect(outcome, isA<RejectedBanglaText>());
      expect((outcome as RejectedBanglaText).reason,
          'unsupported character U+D83D at position 5');
    });

    test('text without Bangla letters is rejected', () {
      expect(parseBanglaText('hello'), isA<RejectedBanglaText>());
      expect(parseBanglaText('123'), isA<RejectedBanglaText>());
      expect(parseBanglaText('   '), isA<ParsedBanglaText>());
    });
  });

  group('inherent vowel fates', () {
    test('the first inherent vowel is always spoken', () {
      expect(fatesOf('রহিম')[0], InherentVowelFate.realizedAtWordStart);
      expect(fatesOf('করিম')[0], InherentVowelFate.realizedAtWordStart);
    });

    test('the final inherent vowel is dropped after a single consonant', () {
      expect(fatesOf('রহিম')[2], InherentVowelFate.deletedAtWordEnd);
      expect(fatesOf('মাসুদ')[2], InherentVowelFate.deletedAtWordEnd);
    });

    test('the final inherent vowel is spoken after a conjunct', () {
      expect(fatesOf('শান্ত')[1], InherentVowelFate.realizedAtWordEnd);
    });

    test('a middle inherent vowel before a spoken syllable is dropped', () {
      expect(fatesOf('ফারজানা')[1], InherentVowelFate.deletedInsideWord);
      expect(fatesOf('সালমা')[1], InherentVowelFate.deletedInsideWord);
    });

    test('a middle inherent vowel before a dropped final vowel is spoken', () {
      expect(fatesOf('কমল')[1], InherentVowelFate.realizedInsideWord);
      expect(fatesOf('বিজয\u09BC')[1], InherentVowelFate.realizedInsideWord);
    });

    test('the middle inherent vowel of a conjunct is kept', () {
      expect(fatesOf('মোস্তফা')[1], InherentVowelFate.realizedInsideWord);
    });

    test('an inherent vowel before a nasal mark is kept', () {
      expect(fatesOf('আর\u0982')[1], InherentVowelFate.realizedInsideWord);
    });

    test('a final inherent vowel before a nasal mark is kept', () {
      expect(fatesOf('র\u0982')[0], InherentVowelFate.realizedAtWordStart);
      expect(fatesOf('আস\u0982')[1], InherentVowelFate.realizedInsideWord);
    });

    test('fates are decided for each word separately', () {
      final plan = planEnglishSpellings(banglaLanguage.normalize('রহিম করিম'));
      expect(plan, isA<ReadySpellingPlan>());
      expect(capitalizeEachWord((plan as ReadySpellingPlan).referenceSpelling),
          'Rohim Korim');
    });
  });

  group('script detection', () {
    test('the script of the input decides the direction', () {
      expect(detectInputScript('মাসুদ'), InputScript.bangla);
      expect(detectInputScript('Masud মাসুদ'), InputScript.bangla);
      expect(detectInputScript('Masud'), InputScript.latin);
      expect(detectInputScript('José'), InputScript.latin);
      expect(detectInputScript('   '), InputScript.empty);
      expect(detectInputScript(''), InputScript.empty);
      expect(detectInputScript('12345'), InputScript.unsupported);
      expect(detectInputScript('مسعود'), InputScript.unsupported);
      expect(detectInputScript('😀'), InputScript.unsupported);
    });
  });

  group('English tokenizing', () {
    test('splits names into sounds', () {
      expect(englishUnitsOf('ayesha'), ['a', 'y', 'e', 'sh', 'a']);
      expect(englishUnitsOf('rayhan'), ['r', 'ay', 'h', 'a', 'n']);
      expect(englishUnitsOf('saddam'), ['s', 'a', 'dd', 'a', 'm']);
      expect(englishUnitsOf('yusuf'), ['yu', 's', 'u', 'f']);
      expect(englishUnitsOf('jahangir'), ['j', 'a', 'h', 'a', 'ng', 'i', 'r']);
      expect(englishUnitsOf('smithy'), ['s', 'm', 'i', 'th', 'y']);
    });

    test('keeps separators and digits', () {
      expect(englishUnitsOf('abdul-karim 2'),
          ['a', 'b', 'd', 'u', 'l', '-', 'k', 'a', 'r', 'i', 'm', ' ', '2']);
    });

    test('rejects characters it cannot read', () {
      final outcome = parseEnglishText('masud😀');
      expect((outcome as RejectedEnglishText).reason,
          'unsupported character U+D83D at position 5');
      expect((parseEnglishText('123') as RejectedEnglishText).reason,
          'the input has no letters');
      expect(parseEnglishText('....'), isA<ParsedEnglishText>());
    });
  });

  group('spelling tables', () {
    test('every English spelling option has a valid similarity', () {
      const consonants =
          'কখগঘঙচছজঝঞটঠডঢণতথদধনপফবভমযরলশষসহ\u09DC\u09DD\u09DF\u09CE';
      final allOptions = <SpellingOptions>[
        for (final consonant in consonants.split(''))
          EnglishSpellingOptions.forConsonant(consonant),
        for (final consonant in consonants.split(''))
          EnglishSpellingOptions.geminated(
              EnglishSpellingOptions.forConsonant(consonant)),
        for (final sound in VowelSound.values) ...[
          EnglishSpellingOptions.forVowel(sound, atWordEnd: false),
          EnglishSpellingOptions.forVowel(sound, atWordEnd: true),
        ],
        for (final fate in InherentVowelFate.values)
          if (EnglishSpellingOptions.forInherentVowel(fate) case final options?)
            options,
        for (final mark in ['\u0982', '\u0983', '\u0981'])
          EnglishSpellingOptions.forNasalMark(mark),
      ];
      allOptions.forEach(expectValidOptions);
    });

    test('every Bangla spelling option has a valid similarity', () {
      const englishUnits = [
        'b',
        'bh',
        'ch',
        'tch',
        'd',
        'dh',
        'f',
        'gh',
        'h',
        'j',
        'jh',
        'k',
        'ck',
        'kh',
        'l',
        'm',
        'n',
        'p',
        'ph',
        'q',
        'r',
        's',
        'sh',
        't',
        'th',
        'v',
        'w',
        'x',
        'y',
        'z',
        'c',
        'g',
        'ng',
      ];
      const vowelUnits = [
        'a',
        'aa',
        'e',
        'i',
        'y',
        'ee',
        'ea',
        'ie',
        'o',
        'oo',
        'u',
        'ou',
        'ow',
        'au',
        'aw',
        'ai',
        'ay',
        'oi',
        'ei',
        'ey',
        'yu',
      ];
      final allOptions = <SpellingOptions>[
        for (final letters in englishUnits)
          for (final isDoubled in [false, true])
            for (final atWordStart in [false, true]) ...[
              BanglaSpellingOptions.forConsonant(letters,
                  isDoubled: isDoubled,
                  atWordStart: atWordStart,
                  nextIsVowel: true,
                  nextVowelLetters: 'e'),
              BanglaSpellingOptions.forConsonant(letters,
                  isDoubled: isDoubled,
                  atWordStart: atWordStart,
                  nextIsVowel: false,
                  nextVowelLetters: null),
            ],
        for (final letters in vowelUnits) ...[
          BanglaSpellingOptions.forVowel(letters, afterConsonant: true),
          BanglaSpellingOptions.forVowel(letters, afterConsonant: false),
          BanglaSpellingOptions.forVowel(letters,
              afterConsonant: true, atWordEnd: true),
        ],
      ];
      allOptions.forEach(expectValidOptions);
    });

    test('options drop the reference and keep the best similarity', () {
      final options = SpellingOptions.of('a', [
        ('b', 0.8),
        ('a', 0.9),
        ('b', 0.9),
        ('c', 0.9),
      ]);
      expect([for (final alt in options.alternatives) alt.text], ['b', 'c']);
      expect(options.alternatives.first.similarity, 0.9);
    });

    test('Bangla tables never produce a decomposed ya with dot', () {
      for (final letters in ['w', 'y']) {
        for (final atWordStart in [false, true]) {
          final options = BanglaSpellingOptions.forConsonant(letters,
              isDoubled: false,
              atWordStart: atWordStart,
              nextIsVowel: true,
              nextVowelLetters: 'a');
          final texts = [
            options.reference,
            for (final alternative in options.alternatives) alternative.text,
          ];
          expect(texts.any((text) => text.contains('য\u09BC')), isFalse);
        }
      }
    });
  });
}
