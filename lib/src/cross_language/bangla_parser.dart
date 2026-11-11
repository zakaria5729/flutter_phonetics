import 'spelling_plan.dart';

const String hasanta = '\u09CD';
const String khandaTa = '\u09CE';
const String yaWithDot = '\u09DF';

const String _consonantLetters =
    'কখগঘঙচছজঝঞটঠডঢণতথদধনপফবভমযরলশষসহ\u09DC\u09DD\u09DF\u09CE';
const String _independentVowelLetters = 'অআইঈউঊঋএঐওঔ';
const String _vowelSignLetters =
    '\u09BE\u09BF\u09C0\u09C1\u09C2\u09C3\u09C7\u09C8\u09CB\u09CC';
const String _nasalMarkLetters = '\u0982\u0983\u0981';
const String _ignoredMarkLetters = '\u200C\u200D\u09BC\u09BD\u09D7';
const String _banglaDigits = '০১২৩৪৫৬৭৮৯';
const String _wordSeparators = ' -.\'';

bool isBanglaConsonant(String character) =>
    _consonantLetters.contains(character);

bool _isIndependentVowel(String character) =>
    _independentVowelLetters.contains(character);

bool _isVowelSign(String character) => _vowelSignLetters.contains(character);

bool _isNasalMark(String character) => _nasalMarkLetters.contains(character);

bool _isIgnoredMark(String character) =>
    _ignoredMarkLetters.contains(character);

bool _isWordSeparator(String character) => _wordSeparators.contains(character);

bool _isAsciiDigit(String character) =>
    character.codeUnitAt(0) >= 0x30 && character.codeUnitAt(0) <= 0x39;

bool _isAsciiLetter(String character) {
  final codeUnit = character.codeUnitAt(0);
  return (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A);
}

sealed class BanglaToken {
  const BanglaToken();
}

final class IndependentVowelToken extends BanglaToken {
  const IndependentVowelToken(this.letter);

  final String letter;
}

final class ConsonantGroupToken extends BanglaToken {
  const ConsonantGroupToken({
    required this.consonants,
    required this.vowelSign,
    required this.endsWithHasanta,
  });

  final List<String> consonants;
  final String? vowelSign;
  final bool endsWithHasanta;

  bool get hasInherentVowel => vowelSign == null && !endsWithHasanta;

  bool get isConjunct => consonants.length > 1;
}

final class NasalMarkToken extends BanglaToken {
  const NasalMarkToken(this.mark);

  final String mark;
}

final class LiteralTextToken extends BanglaToken {
  const LiteralTextToken(this.text);

  final String text;
}

final class WordBreakToken extends BanglaToken {
  const WordBreakToken(this.text);

  final String text;
}

sealed class BanglaParseOutcome {
  const BanglaParseOutcome();
}

final class ParsedBanglaText extends BanglaParseOutcome {
  const ParsedBanglaText(this.tokens);

  final List<BanglaToken> tokens;
}

final class RejectedBanglaText extends BanglaParseOutcome {
  const RejectedBanglaText(this.reason);

  final String reason;
}

BanglaParseOutcome parseBanglaText(String rawText) {
  final text = _withoutIgnoredMarks(rawText);
  final tokens = <BanglaToken>[];
  var index = 0;
  var foundBanglaLetter = false;

  while (index < text.length) {
    final character = text[index];
    if (isBanglaConsonant(character)) {
      foundBanglaLetter = true;
      index = _readConsonantGroup(text, index, tokens);
    } else if (_isIndependentVowel(character)) {
      foundBanglaLetter = true;
      tokens.add(IndependentVowelToken(character));
      index++;
    } else if (_isNasalMark(character)) {
      tokens.add(NasalMarkToken(character));
      index++;
    } else if (_isVowelSign(character) || character == hasanta) {
      index++;
    } else if (_isWordSeparator(character)) {
      tokens.add(WordBreakToken(character));
      index++;
    } else if (_banglaDigits.contains(character)) {
      tokens.add(LiteralTextToken('${_banglaDigits.indexOf(character)}'));
      index++;
    } else if (_isAsciiDigit(character)) {
      tokens.add(LiteralTextToken(character));
      index++;
    } else if (_isAsciiLetter(character)) {
      tokens.add(LiteralTextToken(character.toLowerCase()));
      index++;
    } else {
      return RejectedBanglaText(
          describeUnsupportedCharacter(text.codeUnitAt(index), index));
    }
  }

  final hasContent = tokens.any((token) => token is! WordBreakToken);
  if (!foundBanglaLetter && hasContent) {
    return const RejectedBanglaText('the input has no Bangla letters');
  }
  return ParsedBanglaText(tokens);
}

String _withoutIgnoredMarks(String text) {
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    final character = text[index];
    if (!_isIgnoredMark(character)) buffer.write(character);
  }
  return buffer.toString();
}

int _readConsonantGroup(String text, int start, List<BanglaToken> tokens) {
  final consonants = [text[start]];
  var index = start + 1;
  var endsWithHasanta = text[start] == khandaTa;

  while (!endsWithHasanta && index < text.length && text[index] == hasanta) {
    index++;
    final following = index < text.length ? text[index] : null;
    if (following != null &&
        isBanglaConsonant(following) &&
        following != khandaTa) {
      consonants.add(following);
      index++;
    } else {
      endsWithHasanta = true;
    }
  }

  String? vowelSign;
  if (!endsWithHasanta && index < text.length && _isVowelSign(text[index])) {
    vowelSign = text[index];
    index++;
  }

  tokens.add(ConsonantGroupToken(
    consonants: consonants,
    vowelSign: vowelSign,
    endsWithHasanta: endsWithHasanta,
  ));
  return index;
}
