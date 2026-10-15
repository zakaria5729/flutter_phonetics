import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/protocol/protocol.dart';
import 'package:test/test.dart';

final testLanguage = PhoneticLanguage(
  code: 'xx',
  name: 'Test',
  foldCase: true,
  canonicalSequences: {'ß': 'ss'},
  marks: {0x2D},
  rules: const [
    PhoneticRule(['q', 'x'], 0.9),
    PhoneticRule(['ee', 'i'], 0.8, position: RulePosition.wordEnd),
  ],
);

void main() {
  test('a language defined outside the package works in the engine', () {
    final engine = PhoneticEngine(language: testLanguage);
    expect(engine.error, isNull);
    expect(engine.generate('Qa').matches,
        const [PhoneticMatch('Qa', 100), PhoneticMatch('Xa', 90)]);
    expect(engine.generate('bee').matches.map((match) => match.word),
        ['bee', 'bi']);
    expect(
        engine.generate('beer').matches.map((match) => match.word), ['beer']);
    expect(engine.generate('STRAßE').matches.first.word, 'STRASSE');
    expect(engine.similarity('Qa', 'xA').score, 90);
  });

  test('its definition survives the trip to a worker', () {
    final engine = PhoneticEngine(language: testLanguage);
    final copy = decodeEngineConfig(encodeEngineConfig(engine));
    expect(copy.error, isNull);
    expect(copy.language.code, 'xx');
    expect(copy.language.foldCase, isTrue);
    expect(copy.language.canonicalSequences, {'ß': 'ss'});
    expect(copy.language.marks, {0x2D});
    expect(copy.generate('Qa').matches, engine.generate('Qa').matches);
  });

  test('Phonetics runs it on the background worker', () async {
    final phonetics = Phonetics(language: testLanguage);
    addTearDown(phonetics.dispose);
    expect(phonetics.language.code, 'xx');

    final (:matches, :error) = await phonetics.generate('Qa');
    expect(error, isNull);
    expect(matches, const [PhoneticMatch('Qa', 100), PhoneticMatch('Xa', 90)]);
    expect((await phonetics.similarity('Qa', 'xA')).score, 90);
    expect((await phonetics.rank('Qa', ['xa', 'zz'], minScore: 80)).matches,
        const [PhoneticMatch('xa', 90)]);
  });

  test('languages do not leak into each other', () async {
    final bangla = BanglaPhonetics();
    final english = EnglishPhonetics();
    final custom = Phonetics(language: testLanguage);
    addTearDown(bangla.dispose);
    addTearDown(english.dispose);
    addTearDown(custom.dispose);

    final results = await Future.wait([
      bangla.generateWords('আসাদ', minScore: 90),
      english.generateWords('Asad', minScore: 95),
      custom.generateWords('Qa'),
    ]);
    expect(results[0].words, ['আসাদ', 'আশাদ', 'আষাদ']);
    expect(results[1].words, containsAll(['Asad', 'Assad']));
    expect(results[2].words, ['Qa', 'Xa']);
  });

  test('English rules do not touch Bangla text', () {
    final english = PhoneticEngine(language: englishLanguage);
    expect(
        english.generate('আসাদ').matches, const [PhoneticMatch('আসাদ', 100)]);
  });

  test('Bangla rules do not touch English text', () {
    final bangla = PhoneticEngine(language: banglaLanguage);
    expect(bangla.generate('Asad').matches, const [PhoneticMatch('Asad', 100)]);
  });

  test('an invalid language is reported by Phonetics, not thrown', () async {
    final phonetics = Phonetics(
        language:
            PhoneticLanguage(code: '', name: 'Nameless', rules: const []));
    addTearDown(phonetics.dispose);
    expect(phonetics.workerName, 'unavailable');
    expect((await phonetics.generate('x')).error,
        isA<PhoneticArgumentException>());
  });

  test('rules from another language are rejected by Phonetics', () async {
    final phonetics = Phonetics(
        language: englishLanguage, rules: banglaLanguage.defaultRuleSet);
    addTearDown(phonetics.dispose);
    expect((await phonetics.generate('asad')).error,
        isA<PhoneticArgumentException>());
  });
}
