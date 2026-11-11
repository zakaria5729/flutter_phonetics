import 'spelling_plan.dart';

class BanglaVowelForm {
  const BanglaVowelForm(this.signAfterConsonant, this.standaloneLetters);

  final String signAfterConsonant;
  final String standaloneLetters;
}

const String _hasantaText = '\u09CD';
const double _conjunctAlternativeSimilarity = 0.88;
const double _doubledReducedSimilarity = 0.9;
const String _yaWithNuktaDecomposed = 'য\u09BC';
const String _yaWithDotComposed = '\u09DF';

String _canonicalBangla(String text) =>
    text.replaceAll(_yaWithNuktaDecomposed, _yaWithDotComposed);

SpellingOptions _bangla(String reference,
        [List<(String, double)> alternatives = const []]) =>
    SpellingOptions.of(_canonicalBangla(reference), [
      for (final (text, similarity) in alternatives)
        (_canonicalBangla(text), similarity),
    ]);

abstract final class BanglaSpellingOptions {
  static const BanglaVowelForm _formAa = BanglaVowelForm('\u09BE', 'আ');
  static const BanglaVowelForm _formInherent = BanglaVowelForm('', 'অ');
  static const BanglaVowelForm _formShortI = BanglaVowelForm('\u09BF', 'ই');
  static const BanglaVowelForm _formLongI = BanglaVowelForm('\u09C0', 'ঈ');
  static const BanglaVowelForm _formShortU = BanglaVowelForm('\u09C1', 'উ');
  static const BanglaVowelForm _formLongU = BanglaVowelForm('\u09C2', 'ঊ');
  static const BanglaVowelForm _formE = BanglaVowelForm('\u09C7', 'এ');
  static const BanglaVowelForm _formOi = BanglaVowelForm('\u09C8', 'ঐ');
  static const BanglaVowelForm _formO = BanglaVowelForm('\u09CB', 'ও');
  static const BanglaVowelForm _formOu = BanglaVowelForm('\u09CC', 'ঔ');
  static const BanglaVowelForm _formAaThenI = BanglaVowelForm('\u09BEই', 'আই');
  static const BanglaVowelForm _formAaThenYa =
      BanglaVowelForm('\u09BE\u09DF', 'আ\u09DF');
  static const BanglaVowelForm _formWordStartYu =
      BanglaVowelForm('\u09C1', 'ইউ');
  static const BanglaVowelForm _formWordStartYuWithYa =
      BanglaVowelForm('\u09C1', 'ই\u09DF\u09C1');

  static final Map<String, List<(BanglaVowelForm, double)>> _vowelChoices = {
    'a': [(_formAa, 1.0), (_formInherent, 0.93)],
    'aa': [(_formAa, 1.0), (_formInherent, 0.85)],
    'e': [(_formE, 1.0), (_formInherent, 0.88)],
    'i': [(_formShortI, 1.0), (_formLongI, 0.95)],
    'y': [(_formShortI, 1.0), (_formLongI, 0.95)],
    'ee': [(_formLongI, 1.0), (_formShortI, 0.95)],
    'ea': [(_formLongI, 1.0), (_formShortI, 0.95)],
    'ie': [(_formLongI, 1.0), (_formShortI, 0.95)],
    'o': [(_formO, 1.0), (_formInherent, 0.93)],
    'oo': [(_formLongU, 1.0), (_formShortU, 0.95)],
    'u': [(_formShortU, 1.0), (_formLongU, 0.95), (_formO, 0.85)],
    'ou': [(_formOu, 1.0), (_formShortU, 0.92), (_formO, 0.85)],
    'ow': [(_formOu, 1.0), (_formShortU, 0.92), (_formO, 0.85)],
    'au': [(_formOu, 1.0), (_formO, 0.85)],
    'aw': [(_formOu, 1.0), (_formO, 0.85)],
    'ai': [(_formAaThenI, 1.0), (_formOi, 0.93)],
    'ay': [(_formAaThenYa, 1.0), (_formAaThenI, 0.9)],
    'oi': [(_formOi, 1.0)],
    'ei': [(_formOi, 1.0), (_formE, 0.85)],
    'ey': [(_formE, 1.0), (_formAaThenYa, 0.85)],
    'yu': [(_formWordStartYu, 1.0), (_formWordStartYuWithYa, 0.92)],
  };

  static final List<(BanglaVowelForm, double)> _wordEndAChoices = [
    (_formAa, 1.0),
    (_formInherent, 0.7),
  ];

  static final List<(BanglaVowelForm, double)> _beforeNgOChoices = [
    (_formInherent, 1.0),
    (_formO, 0.9),
  ];

  static final Map<String, SpellingOptions> _consonantOptions = {
    'b': _bangla('ব'),
    'bh': _bangla('ভ', [('ব', 0.9)]),
    'ch': _bangla('চ', [('ছ', 0.93)]),
    'tch': _bangla('চ', [('ছ', 0.9)]),
    'd': _bangla('দ', [('ড', 0.95)]),
    'dh': _bangla('ধ', [('ঢ', 0.93), ('দ', 0.88)]),
    'f': _bangla('ফ'),
    'gh': _bangla('ঘ', [('গ', 0.9)]),
    'h': _bangla('হ'),
    'j': _bangla('জ', [('য', 0.95)]),
    'jh': _bangla('ঝ', [('জ', 0.9)]),
    'k': _bangla('ক', [('খ', 0.85)]),
    'ck': _bangla('ক'),
    'kh': _bangla('খ', [('ক', 0.88)]),
    'l': _bangla('ল'),
    'm': _bangla('ম'),
    'n': _bangla('ন', [('ণ', 0.93)]),
    'p': _bangla('প'),
    'ph': _bangla('ফ', [('প', 0.88)]),
    'q': _bangla('ক', [('খ', 0.8)]),
    'r': _bangla('র'),
    's': _bangla('স', [('শ', 0.93), ('ষ', 0.9)]),
    'sh': _bangla('শ', [('ষ', 0.93), ('স', 0.9)]),
    't': _bangla('ত', [('ট', 0.95)]),
    'th': _bangla('থ', [('ঠ', 0.93), ('ত', 0.9)]),
    'v': _bangla('ভ', [('ব', 0.9)]),
    'w': _bangla('ও\u09DF', [('ব', 0.8)]),
    'x': _bangla('ক\u09CDস', [('ক\u09CDষ', 0.88)]),
    'y': _bangla('\u09DF'),
    'z': _bangla('জ', [('য', 0.93)]),
  };

  static final SpellingOptions _softCOptions = _bangla('স', [('ক', 0.85)]);
  static final SpellingOptions _hardCOptions = _bangla('ক', [('স', 0.8)]);
  static final SpellingOptions _softGOptions = _bangla('জ', [('গ', 0.85)]);
  static final SpellingOptions _hardGOptions = _bangla('গ', [('জ', 0.78)]);
  static final SpellingOptions _wordInitialNOptions = _bangla('ন');
  static final SpellingOptions _tAfterWordInitialSOptions =
      _bangla('ট', [('ত', 0.95)]);
  static final SpellingOptions _wordStartYOptions =
      _bangla('ই\u09DF', [('\u09DF', 0.8)]);
  static final SpellingOptions _ngBeforeVowelOptions =
      _bangla('ঙ\u09CDগ', [('ঙ', 0.88)]);
  static final SpellingOptions _ngElsewhereOptions =
      _bangla('\u0982', [('ঙ\u09CDগ', 0.9), ('ঙ', 0.88)]);

  static const Set<String> _conjunctPairs = {
    'st',
    'sk',
    'sp',
    'sht',
    'nd',
    'nt',
    'nj',
    'mp',
    'mb',
    'bd',
    'kt',
    'ft',
    'pt',
    'ct',
    'gn',
  };

  static SpellingOptions forVowel(
    String letters, {
    required bool afterConsonant,
    bool atWordEnd = false,
    bool beforeNasalNg = false,
  }) {
    final List<(BanglaVowelForm, double)> choices;
    if (atWordEnd && letters == 'a') {
      choices = _wordEndAChoices;
    } else if (beforeNasalNg && letters == 'o') {
      choices = _beforeNgOChoices;
    } else {
      choices = _vowelChoices[letters]!;
    }
    String textOf(BanglaVowelForm form) => _canonicalBangla(
        afterConsonant ? form.signAfterConsonant : form.standaloneLetters);
    return SpellingOptions.of(textOf(choices.first.$1), [
      for (final (form, similarity) in choices.skip(1))
        (textOf(form), similarity),
    ]);
  }

  static SpellingOptions forConsonant(
    String letters, {
    required bool isDoubled,
    required bool atWordStart,
    required bool nextIsVowel,
    required String? nextVowelLetters,
    bool followsWordInitialS = false,
  }) {
    final SpellingOptions single;
    if (letters == 't' && followsWordInitialS) {
      single = _tAfterWordInitialSOptions;
    } else if (letters == 'n' && atWordStart) {
      single = _wordInitialNOptions;
    } else if (letters == 'ng') {
      single = nextIsVowel ? _ngBeforeVowelOptions : _ngElsewhereOptions;
    } else if (letters == 'c') {
      single = _isSoftVowel(nextVowelLetters) ? _softCOptions : _hardCOptions;
    } else if (letters == 'g') {
      single = _isSoftVowel(nextVowelLetters) ? _softGOptions : _hardGOptions;
    } else if (letters == 'y' && atWordStart) {
      single = _wordStartYOptions;
    } else {
      single = _consonantOptions[letters] ?? _bangla('');
    }
    return isDoubled ? _doubled(single) : single;
  }

  static SpellingOptions forConjunctJoin(
    String firstLetters,
    String secondLetters, {
    required bool firstIsAtWordStart,
  }) {
    final joinsAsConjunct = firstIsAtWordStart ||
        secondLetters == 'r' ||
        _conjunctPairs.contains('$firstLetters$secondLetters');
    return joinsAsConjunct
        ? _bangla(_hasantaText, [('', _conjunctAlternativeSimilarity)])
        : _bangla('', [(_hasantaText, _conjunctAlternativeSimilarity)]);
  }

  static bool isNasalGroup(String letters) => letters == 'ng';

  static bool _isSoftVowel(String? vowelLetters) =>
      vowelLetters != null &&
      (vowelLetters.startsWith('e') ||
          vowelLetters.startsWith('i') ||
          vowelLetters == 'y');

  static SpellingOptions _doubled(SpellingOptions single) {
    if (single.reference.length != 1) {
      return SpellingOptions.of(single.reference);
    }
    return SpellingOptions.of(_conjoin(single.reference), [
      (single.reference, _doubledReducedSimilarity),
      for (final alternative in single.alternatives)
        (
          alternative.text.length == 1
              ? _conjoin(alternative.text)
              : alternative.text,
          alternative.similarity,
        ),
    ]);
  }

  static String _conjoin(String letter) => '$letter$_hasantaText$letter';
}
