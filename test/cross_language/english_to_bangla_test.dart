import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

import '../support/cross_language_support.dart';

const Map<String, List<String>> plausibleBanglaByEnglishName = {
  'Masud': ['মাসুদ', 'মাসূদ', 'মাশুদ', 'মাষুদ'],
  'Saddam': ['সাদ্দাম', 'সাদাম'],
  'Mohammad': ['মোহাম্মদ', 'মোহাম্মাদ'],
  'Abdul': ['আব্দুল'],
  'Rahim': ['রহিম', 'রাহিম', 'রহীম'],
  'Karim': ['করিম', 'কারিম'],
  'Farzana': ['ফারজানা', 'ফরজানা'],
  'Nasir': ['নাসির'],
  'Shakib': ['শাকিব', 'সাকিব'],
  'Mostafa': ['মোস্তাফা', 'মোস্তফা'],
  'Hossain': ['হোসাইন'],
  'Wasim': ['ওয\u09BC\u09BEসিম'],
  'Yusuf': ['ইউসুফ'],
  'Ayesha': ['আয\u09BC\u09C7শা'],
  'Jahangir': ['জাহাঙ্গীর', 'জাহাঙ্গির'],
  'Stephen': ['স্টেফেন'],
  'Smith': ['স্মিথ'],
  'Philip': ['ফিলিপ'],
};

const String _vowelSigns =
    '\u09BE\u09BF\u09C0\u09C1\u09C2\u09C3\u09C7\u09C8\u09CB\u09CC';

bool _isConsonant(String character) {
  final codeUnit = character.codeUnitAt(0);
  return (codeUnit >= 0x0995 && codeUnit <= 0x09B9) ||
      codeUnit == 0x09DC ||
      codeUnit == 0x09DD ||
      codeUnit == 0x09DF;
}

void expectStructurallyValidBangla(String word, String source) {
  for (var index = 0; index < word.length; index++) {
    final character = word[index];
    final previous = index > 0 ? word[index - 1] : null;
    final next = index + 1 < word.length ? word[index + 1] : null;
    final reason = 'invalid Bangla "$word" for $source at $index';
    if (_vowelSigns.contains(character)) {
      expect(
          previous != null &&
              (_isConsonant(previous) || '\u09BE\u09C7'.contains(previous)),
          isTrue,
          reason: reason);
    } else if (character == '\u09CD') {
      expect(
          previous != null &&
              _isConsonant(previous) &&
              next != null &&
              _isConsonant(next),
          isTrue,
          reason: reason);
    } else if (character == '\u0982') {
      expect(next == null || !_vowelSigns.contains(next), isTrue,
          reason: reason);
    }
    if (index == 0) {
      expect(character, isNot('ণ'), reason: reason);
      expect(_vowelSigns.contains(character), isFalse, reason: reason);
    }
  }
}

void main() {
  final englishEngine = PhoneticEngine(language: englishLanguage);

  test('English names produce their plausible Bangla spellings', () {
    for (final entry in plausibleBanglaByEnglishName.entries) {
      final words = banglaWords(entry.key);
      for (final spelling in entry.value) {
        expect(words, contains(normalizedBangla(spelling)),
            reason: '${entry.key} should produce $spelling');
      }
    }
  });

  test('the best Bangla reading is the only hundred percent match', () {
    for (final name in plausibleBanglaByEnglishName.keys) {
      final matches = banglaMatches(name);
      expect(matches.first.score, 100, reason: name);
      expect(matches.skip(1).every((match) => match.score < 100), isTrue,
          reason: name);
      expect(matches.first.changes, isEmpty, reason: name);
    }
  });

  test('Masud matches the documented example', () {
    final matches = banglaMatches('Masud', minScore: 90);
    expect([for (final match in matches) match.word].take(5),
        ['মাসুদ', 'মাসূদ', 'মাসুড', 'মসুদ', 'মাশুদ']);
    expect([for (final match in matches) match.score].take(5),
        [100, 95, 95, 93, 93]);
  });

  test('best readings of common English names', () {
    const bestReadings = {
      'Masud': 'মাসুদ',
      'Abdul': 'আব্দুল',
      'Mostafa': 'মোস্তাফা',
      'Smith': 'স্মিথ',
      'Saddam': 'সাদ্দাম',
      'Islam': 'ইসলাম',
      'Salman': 'সালমান',
      'Ahmed': 'আহমেদ',
      'Bangla': 'বা\u0982লা',
      'Rongpur': 'র\u0982পুর',
      'Ayesha': 'আয\u09BC\u09C7শা',
      'Wasim': 'ওয\u09BC\u09BEসিম',
      'Yusuf': 'ইউসুফ',
      'Raisa': 'রাইসা',
      'Abdul Karim': 'আব্দুল কারিম',
      'Abdul-Karim': 'আব্দুল-কারিম',
      'Masud123': 'মাসুদ123',
      'Jahangir': 'জাহাঙ্গির',
    };
    for (final entry in bestReadings.entries) {
      expect(banglaWords(entry.key).first, normalizedBangla(entry.value),
          reason: entry.key);
    }
  });

  test('upper and lower case give identical results', () {
    expect(banglaMatches('Masud'), banglaMatches('MASUD'));
    expect(banglaMatches('Masud'), banglaMatches('masud'));
    expect(banglaMatches('Jose'), banglaMatches('José'));
  });

  test('different English spellings of one sound reach the same Bangla name',
      () {
    expect(banglaWords('Masood'), contains('মাসুদ'));
    expect(banglaWords('Masoud'), contains('মাসুদ'));
    expect(banglaWords('Mahmood'), contains('মাহমুদ'));
    expect(banglaWords('Mahmoud'), contains('মাহমুদ'));
    expect(banglaWords('Raheem'), contains('রহিম'));
    expect(banglaWords('Phillip'), contains('ফিলিপ'));
    expect(banglaWords('Filip'), contains('ফিলিপ'));
  });

  test('consonants with several Bangla letters offer them all', () {
    expect(banglaWords('Masud'), containsAll(['মাসুদ', 'মাশুদ', 'মাষুদ']));
    expect(banglaWords('Tipu'), containsAll(['তিপু', 'টিপু']));
    expect(banglaWords('Zakir'), containsAll(['জাকির', 'যাকির']));
  });

  test('doubled English letters are kept or reduced in Bangla', () {
    expect(banglaWords('Saddam'), containsAll(['সাদ্দাম', 'সাদাম']));
    expect(banglaWords('Hossain'), contains('হোসাইন'));
    expect(banglaWords('Hossain').first, 'হোস্সাইন');
    expect(
        banglaMatches('Hossain')
            .firstWhere((match) => match.word == 'হোসাইন')
            .score,
        90);
  });

  test('the vowel sign or the standalone letter follows from the context', () {
    expect(banglaWords('Rayhan').first, normalizedBangla('রায\u09BCহান'));
    expect(banglaWords('Chowdhury').first, 'চৌধুরি');
  });

  test('every generated Bangla spelling is structurally valid', () {
    final names = [
      ...plausibleBanglaByEnglishName.keys,
      'Abdul Karim',
      'Chowdhury',
      'Rahman',
      'Tanvir',
      'Syed',
      'Ng',
      'Sing',
      'Kingdom',
    ];
    for (final name in names) {
      for (final match in banglaMatches(name, minScore: 40, maxResults: 500)) {
        expectStructurallyValidBangla(match.word, name);
      }
    }
  });

  test('the order is the same on every run and has no duplicates', () {
    for (final name in plausibleBanglaByEnglishName.keys) {
      final first = banglaMatches(name, minScore: 50);
      expect(first, banglaMatches(name, minScore: 50));
      expect({for (final match in first) match.word}.length, first.length,
          reason: name);
      final scores = [for (final match in first) match.score];
      expect(scores, orderedEquals(sortedDescending(scores)));
    }
  });

  test('English input gives the existing English variants in the English list',
      () {
    for (final name in ['Philip', 'Stephen', 'Catherine', 'Jackson']) {
      final result = crossLanguageEngine.generate(name,
          languages: bothLanguages, minScore: 80);
      expect(result.error, isNull);
      final existing = englishEngine.generate(name, minScore: 80);
      expect(result.english.matches, existing.matches, reason: name);
      expect([for (final match in result.english.matches) match.changes],
          [for (final match in existing.matches) match.changes]);
    }
    final philip = englishMatches('Philip', minScore: 90);
    expect([for (final match in philip) match.word].take(5),
        ['Philip', 'Filip', 'Phillip', 'Philipp', 'Fillip']);
    expect([for (final match in philip) match.score].take(5),
        [100, 95, 95, 95, 90.25]);
  });

  test('English input gives both lists independently', () {
    final result = crossLanguageEngine.generate('Masud',
        languages: bothLanguages, minScore: 90);
    expect(result.error, isNull);
    expect(result.bangla.matches.first.word, 'মাসুদ');
    expect(result.english.matches.first.word, 'Masud');
    expect(
        result.bangla.matches
            .every((match) => match.word.codeUnits.any((unit) => unit > 0x7F)),
        isTrue);
    expect(
        result.english.matches.every(
            (match) => match.word.codeUnits.every((unit) => unit < 0x80)),
        isTrue);
  });

  test('English input limits apply to each list separately', () {
    final result = crossLanguageEngine.generate(
      'Masud',
      languages: bothLanguages,
      banglaOptions: const PhoneticSearchOptions(minScore: 95, maxResults: 5),
      englishOptions: const PhoneticSearchOptions(minScore: 90, maxResults: 2),
    );
    expect(result.bangla.matches.every((match) => match.score >= 95), isTrue);
    expect(result.english.matches.length, 2);
  });

  test('includeOriginal decides whether the English input stays in its list',
      () {
    final kept = crossLanguageEngine.generate('Philip',
        languages: bothLanguages, minScore: 90);
    final dropped = crossLanguageEngine.generate('Philip',
        languages: bothLanguages, minScore: 90, includeOriginal: false);
    expect([for (final match in kept.english.matches) match.word],
        contains('Philip'));
    expect([for (final match in dropped.english.matches) match.word],
        isNot(contains('Philip')));
    expect(dropped.bangla.matches.first.word, 'ফিলিপ');
  });

  test('maxChanges applies to both lists for English input', () {
    final result = crossLanguageEngine.generate('Masud',
        languages: bothLanguages, minScore: 0, maxChanges: 0);
    expect([for (final match in result.bangla.matches) match.word], ['মাসুদ']);
    expect([for (final match in result.english.matches) match.word], ['Masud']);
  });

  test('an emoji inside an English name fails only the Bangla list', () {
    final result =
        crossLanguageEngine.generate('Masud😀', languages: bothLanguages);
    expect(result.bangla.error, isA<PhoneticArgumentException>());
    expect(result.english.error, isNull);
    expect(result.english.matches, isNotEmpty);
    expect(result.error, same(result.bangla.error));
  });

  test('a name with a digit run keeps it in both lists', () {
    expect(banglaWords('Masud 2').first, 'মাসুদ 2');
    expect(englishMatches('Masud 2'),
        englishEngine.generate('Masud 2', maxResults: 300).matches);
  });
}
