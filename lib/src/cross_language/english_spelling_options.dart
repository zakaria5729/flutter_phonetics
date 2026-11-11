import 'bangla_parser.dart';
import 'inherent_vowel_rules.dart';
import 'spelling_plan.dart';

enum VowelSound { openO, a, i, u, ri, e, oi, o, ou }

const double _geminateReducedSimilarity = 0.9;

abstract final class EnglishSpellingOptions {
  static final Map<String, SpellingOptions> _consonantOptions = {
    'ক': SpellingOptions.of('k', [('q', 0.85)]),
    'খ': SpellingOptions.of('kh', [('k', 0.88)]),
    'গ': SpellingOptions.of('g'),
    'ঘ': SpellingOptions.of('gh', [('g', 0.9)]),
    'ঙ': SpellingOptions.of('ng', [('n', 0.85)]),
    'চ': SpellingOptions.of('ch'),
    'ছ': SpellingOptions.of('ch', [('chh', 0.95), ('s', 0.8), ('sh', 0.8)]),
    'জ': SpellingOptions.of('j', [('z', 0.95)]),
    'ঝ': SpellingOptions.of('jh', [('j', 0.9), ('z', 0.85)]),
    'ঞ': SpellingOptions.of('n', [('ny', 0.85)]),
    'ট': SpellingOptions.of('t'),
    'ঠ': SpellingOptions.of('th', [('t', 0.9)]),
    'ড': SpellingOptions.of('d'),
    'ঢ': SpellingOptions.of('dh', [('d', 0.9)]),
    'ণ': SpellingOptions.of('n'),
    'ত': SpellingOptions.of('t', [('th', 0.8)]),
    'থ': SpellingOptions.of('th', [('t', 0.9)]),
    'দ': SpellingOptions.of('d'),
    'ধ': SpellingOptions.of('dh', [('d', 0.9)]),
    'ন': SpellingOptions.of('n'),
    'প': SpellingOptions.of('p'),
    'ফ': SpellingOptions.of('f', [('ph', 0.85)]),
    'ব': SpellingOptions.of('b', [('v', 0.78)]),
    'ভ': SpellingOptions.of('bh', [('v', 0.93), ('b', 0.9)]),
    'ম': SpellingOptions.of('m'),
    'য': SpellingOptions.of('j', [('z', 0.95), ('y', 0.8)]),
    yaWithDot: SpellingOptions.of('y'),
    'র': SpellingOptions.of('r'),
    'ল': SpellingOptions.of('l'),
    'শ': SpellingOptions.of('sh', [('s', 0.9)]),
    'ষ': SpellingOptions.of('sh', [('s', 0.9)]),
    'স': SpellingOptions.of('s', [('sh', 0.9)]),
    'হ': SpellingOptions.of('h'),
    '\u09DC': SpellingOptions.of('r', [('rh', 0.85)]),
    '\u09DD': SpellingOptions.of('r', [('rh', 0.9)]),
    khandaTa: SpellingOptions.of('t', [('th', 0.85)]),
  };

  static final Map<VowelSound, SpellingOptions> _vowelOptions = {
    VowelSound.openO: SpellingOptions.of('o', [('a', 0.95)]),
    VowelSound.a: SpellingOptions.of('a', [('aa', 0.88)]),
    VowelSound.i: SpellingOptions.of('i', [('ee', 0.93), ('e', 0.85)]),
    VowelSound.u:
        SpellingOptions.of('u', [('oo', 0.95), ('ou', 0.9), ('o', 0.8)]),
    VowelSound.ri: SpellingOptions.of('ri', [('ru', 0.85), ('rri', 0.85)]),
    VowelSound.e: SpellingOptions.of('e', [('ay', 0.85), ('a', 0.8)]),
    VowelSound.oi:
        SpellingOptions.of('oi', [('ai', 0.95), ('oy', 0.92), ('ay', 0.88)]),
    VowelSound.o: SpellingOptions.of('o', [('u', 0.9), ('oo', 0.8)]),
    VowelSound.ou:
        SpellingOptions.of('ou', [('ow', 0.95), ('au', 0.92), ('aw', 0.88)]),
  };

  static final Map<VowelSound, SpellingOptions> _wordEndVowelOptions = {
    VowelSound.i:
        SpellingOptions.of('i', [('ee', 0.93), ('e', 0.85), ('y', 0.85)]),
  };

  static final Map<String, SpellingOptions> _clusterOptions = {
    'ক$hasantaষ':
        SpellingOptions.of('ksh', [('kkh', 0.95), ('x', 0.85), ('kh', 0.85)]),
    'জ$hasantaঞ':
        SpellingOptions.of('gg', [('gy', 0.95), ('jn', 0.88), ('gn', 0.88)]),
    'হ$hasantaম': SpellingOptions.of('hm', [('mm', 0.85)]),
  };

  static final Map<String, SpellingOptions> _wordStartClusterOptions = {
    'ক$hasantaষ': SpellingOptions.of('kh', [('ksh', 0.95), ('kkh', 0.9)]),
  };

  static final SpellingOptions _velarNasalOptions =
      SpellingOptions.of('n', [('ng', 0.88)]);
  static final SpellingOptions _rephaOptions = SpellingOptions.of('r');
  static final SpellingOptions _yaPhalaOptions =
      SpellingOptions.of('y', [('', 0.88)]);
  static final SpellingOptions _baPhalaOptions =
      SpellingOptions.of('w', [('', 0.88), ('b', 0.8)]);
  static final SpellingOptions _yaAfterVowelOptions =
      SpellingOptions.of('y', [('i', 0.93)]);
  static final SpellingOptions _wordStartWaOptions =
      SpellingOptions.of('w', [('oy', 0.75)]);
  static final SpellingOptions _yuVowelPairOptions =
      SpellingOptions.of('yu', [('you', 0.9), ('iu', 0.9), ('yoo', 0.85)]);

  static final Map<InherentVowelFate, SpellingOptions> _inherentVowelOptions = {
    InherentVowelFate.realizedAtWordStart:
        SpellingOptions.of('o', [('a', 0.95)]),
    InherentVowelFate.realizedInsideWord:
        SpellingOptions.of('o', [('a', 0.95), ('e', 0.85)]),
    InherentVowelFate.realizedAtWordEnd:
        SpellingOptions.of('o', [('a', 0.9), ('', 0.85)]),
    InherentVowelFate.deletedInsideWord: SpellingOptions.of('', [('a', 0.8)]),
  };

  static final Map<String, SpellingOptions> _nasalMarkOptions = {
    '\u0982': SpellingOptions.of('ng', [('n', 0.85)]),
    '\u0983': SpellingOptions.of('h', [('', 0.9)]),
    '\u0981': SpellingOptions.of('n', [('', 0.85)]),
  };

  static const Set<String> _velarConsonants = {'ক', 'খ', 'গ', 'ঘ'};

  static SpellingOptions forConsonant(String consonant) =>
      _consonantOptions[consonant] ?? SpellingOptions.of('');

  static SpellingOptions forVowel(VowelSound sound,
          {required bool atWordEnd}) =>
      (atWordEnd ? _wordEndVowelOptions[sound] : null) ?? _vowelOptions[sound]!;

  static SpellingOptions? forCluster(String first, String second,
      {required bool atWordStart}) {
    final key = '$first$hasanta$second';
    return (atWordStart ? _wordStartClusterOptions[key] : null) ??
        _clusterOptions[key];
  }

  static SpellingOptions forNasalConsonantBeforeVelar() => _velarNasalOptions;

  static SpellingOptions? forPhala(String consonant) => switch (consonant) {
        'র' => _rephaOptions,
        'য' => _yaPhalaOptions,
        'ব' => _baPhalaOptions,
        _ => null,
      };

  static SpellingOptions forYaAfterVowel() => _yaAfterVowelOptions;

  static SpellingOptions forWordStartWa() => _wordStartWaOptions;

  static SpellingOptions forYuVowelPair() => _yuVowelPairOptions;

  static SpellingOptions? forInherentVowel(InherentVowelFate fate) =>
      _inherentVowelOptions[fate];

  static SpellingOptions forNasalMark(String mark) => _nasalMarkOptions[mark]!;

  static bool isVelar(String consonant) => _velarConsonants.contains(consonant);

  static SpellingOptions geminated(SpellingOptions single) {
    final doubledReference = _doubleLetters(single.reference);
    return SpellingOptions.of(doubledReference, [
      (single.reference, _geminateReducedSimilarity),
      for (final alternative in single.alternatives)
        (_doubleLetters(alternative.text), alternative.similarity),
    ]);
  }

  static String _doubleLetters(String text) =>
      text.length == 2 && text[1] == 'h' ? '${text[0]}$text' : '$text$text';
}
