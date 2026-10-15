import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/core/text_normalizer.dart';
import 'package:test/test.dart';

void main() {
  group('Bangla', () {
    test('composes nukta letters', () {
      final withNukta =
          String.fromCharCodes([0x09AC, 0x09BE, 0x09A1, 0x09BC, 0x09BF]);
      final precomposed =
          String.fromCharCodes([0x09AC, 0x09BE, 0x09DC, 0x09BF]);
      expect(banglaLanguage.normalize(withNukta), precomposed);
      expect(banglaLanguage.normalize(precomposed), precomposed);
    });

    test('turns the old khanda ta and split vowel signs into one form', () {
      expect(
          banglaLanguage
              .normalize(String.fromCharCodes([0x09A4, 0x09CD, 0x200D])),
          String.fromCharCodes([0x09CE]));
      expect(
          banglaLanguage
              .normalize(String.fromCharCodes([0x0995, 0x09C7, 0x09BE])),
          String.fromCharCodes([0x0995, 0x09CB]));
    });

    test('keeps case and plain text as they are', () {
      expect(banglaLanguage.normalize('আসাদ'), 'আসাদ');
      expect(banglaLanguage.normalize('Asad'), 'Asad');
    });

    test('knows its marks', () {
      final normalizer = banglaLanguage.normalizer;
      expect(normalizer.isMark(0x09CD), isTrue);
      expect(normalizer.isMark(0x09A1), isFalse);
      expect(normalizer.isMark(-1), isFalse);
    });
  });

  group('English', () {
    test('folds case', () {
      expect(englishLanguage.normalize('Asad'), 'asad');
      expect(englishLanguage.normalize('ASAD KHAN'), 'asad khan');
    });

    test('removes accents, precomposed or not', () {
      expect(englishLanguage.normalize('José'), 'jose');
      expect(
          englishLanguage
              .normalize(String.fromCharCodes([0x4A, 0x6F, 0x73, 0x65, 0x301])),
          'jose');
      expect(englishLanguage.normalize('Zoë Müller'), 'zoe muller');
      expect(englishLanguage.normalize('Strauß'), 'strauss');
      expect(englishLanguage.normalize('Łukasz'), 'lukasz');
    });

    test('makes typographic apostrophes plain', () {
      expect(englishLanguage.normalize('O’Brien'), "o'brien");
    });

    test('knows its marks', () {
      final normalizer = englishLanguage.normalizer;
      expect(normalizer.isMark(0x27), isTrue);
      expect(normalizer.isMark(0x2D), isTrue);
      expect(normalizer.isMark(0x61), isFalse);
    });
  });

  group('whitespace', () {
    test('is trimmed and collapsed', () {
      expect(englishLanguage.normalize('  Mary   Ann \t'), 'mary ann');
      expect(englishLanguage.normalize('Mary\nAnn'), 'mary ann');
      expect(englishLanguage.normalize('Mary Ann'), 'mary ann');
      expect(banglaLanguage.normalize('  আসাদ   খান '), 'আসাদ খান');
    });

    test('blank text becomes empty', () {
      expect(englishLanguage.normalize('   '), isEmpty);
      expect(banglaLanguage.normalize(''), isEmpty);
    });
  });

  group('letter case', () {
    final normalizer = englishLanguage.normalizer;

    test('is detected', () {
      expect(normalizer.detectCase('asad'), LetterCase.lower);
      expect(normalizer.detectCase('Asad'), LetterCase.title);
      expect(normalizer.detectCase('Mary Ann'), LetterCase.title);
      expect(normalizer.detectCase('ASAD'), LetterCase.upper);
      expect(normalizer.detectCase('mary Ann'), LetterCase.lower);
      expect(normalizer.detectCase('123'), LetterCase.unchanged);
      expect(
          banglaLanguage.normalizer.detectCase('Asad'), LetterCase.unchanged);
    });

    test('is applied', () {
      expect(normalizer.applyCase('assad', LetterCase.title), 'Assad');
      expect(normalizer.applyCase('mary ann', LetterCase.title), 'Mary Ann');
      expect(normalizer.applyCase('assad', LetterCase.upper), 'ASSAD');
      expect(normalizer.applyCase('assad', LetterCase.lower), 'assad');
    });
  });

  test('longer sequences win over shorter ones', () {
    final language = PhoneticLanguage(
      code: 'xx',
      name: 'Test',
      rules: const [],
      canonicalSequences: {'ab': 'X', 'abc': 'Y'},
    );
    expect(language.normalize('abc ab'), 'Y X');
  });
}
