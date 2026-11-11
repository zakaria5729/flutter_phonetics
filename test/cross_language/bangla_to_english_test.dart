import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

import '../support/cross_language_support.dart';

const Map<String, List<String>> plausibleSpellingsByName = {
  'মাসুদ': ['Masud', 'Masood', 'Masoud', 'Mashud'],
  'সাদ্দাম': ['Saddam', 'Sadam', 'Sadaam'],
  'মোজাফফর': ['Mozaffar', 'Muzaffar', 'Mozafar'],
  'মোহাম্মদ': ['Mohammad', 'Muhammad', 'Mohammed', 'Mohamad'],
  'আব্দুল': ['Abdul', 'Abdool'],
  'রহিম': ['Rahim', 'Raheem', 'Rohim'],
  'করিম': ['Karim', 'Kareem'],
  'ফারজানা': ['Farzana', 'Farjana'],
  'নাসির': ['Nasir', 'Naseer', 'Naser'],
  'শাকিব': ['Shakib', 'Sakib'],
  'জাহাঙ্গীর': ['Jahangir', 'Jahangeer'],
  'ওয\u09BC\u09BEসিম': ['Wasim', 'Waseem'],
  'রায\u09BCহান': ['Rayhan', 'Raihan'],
  'ইউসুফ': ['Yusuf', 'Yousuf'],
  'তানভীর': ['Tanvir', 'Tanbir'],
};

void main() {
  test('common Bangladeshi names produce their plausible English spellings',
      () {
    for (final entry in plausibleSpellingsByName.entries) {
      final words = englishWords(entry.key);
      for (final spelling in entry.value) {
        expect(words, contains(spelling),
            reason: '${entry.key} should produce $spelling');
      }
    }
  });

  test('Masud matches the documented example', () {
    final matches = englishMatches('মাসুদ', minScore: 90);
    expect([for (final match in matches) match.word],
        ['Masud', 'Masood', 'Masoud', 'Mashud']);
    expect([for (final match in matches) match.score], [100, 95, 90, 90]);
    final belowNinety = englishMatches('মাসুদ', minScore: 85);
    expect(
        belowNinety.map((match) => (match.word, match.score)),
        containsAll([
          ('Maasud', 88),
          ('Mashood', 85.5),
        ]));
  });

  test('the best reading is the only hundred percent match', () {
    for (final name in plausibleSpellingsByName.keys) {
      final matches = englishMatches(name);
      expect(matches.first.score, 100, reason: name);
      expect(matches.skip(1).every((match) => match.score < 100), isTrue,
          reason: name);
      expect(matches.first.changes, isEmpty, reason: name);
    }
  });

  test('similar sounding Bangla letters give the same English candidates', () {
    expect(englishWords('মাশুদ'), englishWords('মাষুদ'));
    expect(
        englishWords('টিপু', minScore: 85), englishWords('তিপু', minScore: 85));
    expect(englishWords('টিপু'), contains('Tipu'));
    expect(englishWords('তিপু'), contains('Tipu'));
    expect(englishWords('ইছলাম'), contains('Islam'));
    expect(englishWords('ইশলাম'), contains('Islam'));
    expect(englishWords('মাশুদ', minScore: 90), contains('Masud'));
    expect(englishWords('মাসুদ', minScore: 90), contains('Mashud'));
  });

  test('the same vowel sound written differently gives the same English', () {
    expect(englishWords('রহিম'), englishWords('রহীম'));
    expect(englishWords('মাসুদ'), englishWords('মাসূদ'));
    expect(englishWords('আলী'), englishWords('আলি'));
  });

  test('ja and ya both cover the J and Z sounds', () {
    for (final name in ['জাকির', 'যাকির']) {
      final words = englishWords(name);
      expect(words, containsAll(['Jakir', 'Zakir']));
    }
  });

  test('aspirated and unaspirated consonants are both offered', () {
    expect(englishWords('খালেদ'), containsAll(['Khaled', 'Kaled']));
    expect(englishWords('ঢাকা'), containsAll(['Dhaka', 'Daka']));
  });

  test('nasal signs become English nasal spellings', () {
    expect(englishWords('র\u0982পুর'), containsAll(['Rongpur', 'Rangpur']));
    expect(englishWords('বা\u0982লাদেশ'), contains('Bangladesh'));
    expect(englishWords('চা\u0981দ').first, 'Chand');
    expect(englishWords('চা\u0981দ'), contains('Chad'));
  });

  test('doubled consonants from conjuncts are kept or reduced', () {
    final saddam = englishMatches('সাদ্দাম');
    expect(saddam.first.word, 'Saddam');
    expect(saddam.firstWhere((match) => match.word == 'Sadam').score, 90);
    expect(englishWords('জান্নাত'), containsAll(['Jannat', 'Janat']));
    expect(englishWords('আব্দুল্লাহ'), containsAll(['Abdullah', 'Abdulah']));
  });

  test('repeated letters without a hasanta are one doubled sound', () {
    final words = englishWords('মোজাফফর');
    expect(words, containsAll(['Mozaffar', 'Mozafar']));
    expect(words.any((word) => word.contains('fff')), isFalse);
  });

  test('conjuncts with special sounds are handled as units', () {
    expect(englishWords('বিজ্ঞান'), containsAll(['Biggan', 'Bigyan']));
    expect(englishWords('রক্ষা'), contains('Raksha'));
    expect(englishWords('ক্ষমা'), containsAll(['Khoma', 'Kshoma']));
    expect(englishWords('ইব্রাহিম'), contains('Ibrahim'));
    expect(englishWords('স্বপন'), containsAll(['Swapan', 'Sopon']));
    expect(englishWords('মোস্তফা'), contains('Mostafa'));
    expect(englishWords('আসাদুজ্জামান'), contains('Asaduzzaman'));
  });

  test('inherent vowels are spelled or dropped following the pronunciation',
      () {
    expect(englishWords('রহিম').first, 'Rohim');
    expect(englishWords('ফারজানা').first, 'Farjana');
    expect(englishWords('শান্ত').first, 'Shanto');
    expect(englishWords('কমল').first, 'Komol');
    expect(englishWords('মোস্তফা').first, 'Mostofa');
    expect(englishWords('সালমা').first, 'Salma');
    expect(englishWords('মোহাম্মদ').first, 'Mohammod');
  });

  test('word final conjuncts may keep or drop their last vowel', () {
    expect(englishWords('শান্ত'), containsAll(['Shanto', 'Shanta', 'Shant']));
  });

  test('several words are capitalised and keep their separators', () {
    final matches = englishMatches('মোহাম্মদ আব্দুল');
    expect(matches.first.word, 'Mohammod Abdul');
    expect(
        [for (final match in matches) match.word], contains('Muhammad Abdul'));
    expect(englishMatches('আব্দুল-করিম').first.word, 'Abdul-Korim');
    expect(englishMatches('মো. হাসান').first.word, 'Mo. Hasan');
  });

  test('digits are carried over', () {
    expect(englishMatches('মাসুদ১২৩').first.word, 'Masud123');
  });

  test('different Unicode forms of one name give one result', () {
    expect(englishWords('ব\u09DC'), englishWords('বড\u09BC'));
    expect(englishWords('আ\u09DFেশা'), englishWords('আয\u09BCেশা'));
    expect(englishWords('জগ\u09CE'), englishWords('জগত\u09CD\u200D'));
    expect(englishWords('মোহাম্মদ'), englishWords('ম\u09C7\u09BEহাম্মদ'));
    expect(englishWords('রহিম'), englishWords('রহ\u200Cিম'));
    expect(englishWords('আসাদ'), englishWords('  আসাদ  '));
  });

  test('results have no duplicates and are sorted best first', () {
    final names = [
      ...plausibleSpellingsByName.keys,
      'মোহাম্মদ আব্দুল',
      'আসাদুজ্জামান',
    ];
    for (final name in names) {
      final matches = englishMatches(name, minScore: 50, maxResults: 500);
      final words = [for (final match in matches) match.word];
      expect(words.toSet().length, words.length, reason: 'duplicates $name');
      final scores = [for (final match in matches) match.score];
      expect(scores, orderedEquals(sortedDescending(scores)));
      expect(scores.every((score) => score >= 50 && score <= 100), isTrue);
    }
  });

  test('the order is the same on every run', () {
    for (final name in plausibleSpellingsByName.keys) {
      expect(englishMatches(name), englishMatches(name));
    }
  });

  test('scores are the product of the chosen alternatives', () {
    final masood =
        englishMatches('মাসুদ').firstWhere((match) => match.word == 'Masood');
    expect(masood.score, 95);
    expect(masood.changes.single.from, 'u');
    expect(masood.changes.single.to, 'oo');

    final mashood =
        englishMatches('মাসুদ').firstWhere((match) => match.word == 'Mashood');
    expect(mashood.score, 85.5);
    expect(mashood.changes.length, 2);
  });

  test('maxChanges limits how far a spelling may drift from the best reading',
      () {
    expect([
      for (final match in englishMatches('মাসুদ', minScore: 0, maxChanges: 0))
        match.word
    ], [
      'Masud'
    ]);
    final oneChange = englishMatches('মাসুদ', minScore: 0, maxChanges: 1);
    expect(oneChange.every((match) => match.changes.length <= 1), isTrue);
    expect(oneChange.length, greaterThan(1));
  });

  test('minScore and maxResults filter English spellings', () {
    expect(
        [for (final match in englishMatches('মাসুদ', minScore: 95)) match.word],
        ['Masud', 'Masood']);
    expect(englishMatches('মাসুদ', minScore: 0).length,
        greaterThan(englishMatches('মাসুদ', minScore: 90).length));
    expect(englishMatches('মাসুদ', minScore: 0, maxResults: 3).length, 3);
    expect(englishMatches('মাসুদ', minScore: 0, maxResults: 1).length, 1);
  });

  test('empty and blank input give no English spellings and no error', () {
    for (final blank in ['', ' ', '   \t\n']) {
      final result =
          crossLanguageEngine.generate(blank, languages: englishOnly);
      expect(result.error, isNull);
      expect(result.english.matches, isEmpty);
    }
  });

  test('input that is not a Bangla name is reported as an error', () {
    for (final invalid in ['12345', 'مسعود', 'मसूद', 'মাসুদ😀']) {
      final result =
          crossLanguageEngine.generate(invalid, languages: englishOnly);
      expect(result.english.error, isA<PhoneticArgumentException>(),
          reason: invalid);
      expect(result.english.matches, isEmpty, reason: invalid);
    }
  });

  test('stray Bangla marks are ignored instead of failing', () {
    final loneVowelSign =
        crossLanguageEngine.generate('\u09BE', languages: englishOnly);
    expect(loneVowelSign.error, isNull);
    expect(loneVowelSign.english.matches, isEmpty);
    expect(englishMatches('মাসুদ্').first.word, 'Masud');
    expect(englishMatches('ক্').first.word, 'K');
  });

  test('a very long input stays bounded by the result limit', () {
    final longName = List.filled(40, 'আসাদুজ্জামান').join(' ');
    final matches = englishMatches(longName, minScore: 0, maxResults: 200);
    expect(matches.length, lessThanOrEqualTo(200));
    expect(matches, isNotEmpty);
    expect({for (final match in matches) match.word}.length, matches.length);
  });
}
