import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

void main() {
  final engine = PhoneticEngine(language: englishLanguage);

  test('the engine defaults to minScore 70 and maxResults 50', () {
    final matches = engine.generate('Christopher').matches;
    expect(matches.length, 50);
    expect(matches.every((match) => match.score >= 70), isTrue);
    expect(engine.generate('Christopher', minScore: 70, maxResults: 50).matches,
        matches);
    expect(engine.generateWords('Christopher').words.length, 50);
  });

  test('a name with few variants returns only those at 70 or more', () {
    final matches = engine.generate('Asad').matches;
    final everything =
        engine.generate('Asad', minScore: 0, maxResults: null).matches;
    expect(matches,
        everything.where((match) => match.score >= 70).take(50).toList());
    expect(matches.length, lessThan(everything.length));
  });

  test('Phonetics uses the same defaults', () async {
    final phonetics = EnglishPhonetics();
    addTearDown(phonetics.dispose);
    final fromWorker = (await phonetics.generate('Christopher')).matches;
    expect(fromWorker, engine.generate('Christopher').matches);
    expect(fromWorker.length, 50);
    expect((await phonetics.generateWords('Christopher')).words.length, 50);
  });
}
