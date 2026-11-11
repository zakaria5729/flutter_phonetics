import 'spelling_plan.dart';

sealed class EnglishUnit {
  const EnglishUnit();
}

final class ConsonantUnit extends EnglishUnit {
  const ConsonantUnit(this.letters, {this.isDoubled = false});

  final String letters;
  final bool isDoubled;
}

final class VowelUnit extends EnglishUnit {
  const VowelUnit(this.letters);

  final String letters;
}

final class LiteralUnit extends EnglishUnit {
  const LiteralUnit(this.text);

  final String text;
}

final class EnglishWordBreakUnit extends EnglishUnit {
  const EnglishWordBreakUnit(this.text);

  final String text;
}

sealed class EnglishParseOutcome {
  const EnglishParseOutcome();
}

final class ParsedEnglishText extends EnglishParseOutcome {
  const ParsedEnglishText(this.units);

  final List<EnglishUnit> units;
}

final class RejectedEnglishText extends EnglishParseOutcome {
  const RejectedEnglishText(this.reason);

  final String reason;
}

const List<String> _consonantDigraphs = [
  'tch',
  'sh',
  'ch',
  'kh',
  'gh',
  'ph',
  'bh',
  'dh',
  'th',
  'jh',
  'ng',
  'ck',
];

const List<String> _vowelDigraphs = [
  'aa',
  'ee',
  'ea',
  'ie',
  'oo',
  'ou',
  'ow',
  'ai',
  'ay',
  'oi',
  'ei',
  'ey',
  'au',
  'aw',
];

const String _plainVowels = 'aeiou';
const String _wordSeparators = ' -.\'';

bool _isLowercaseLetter(String character) =>
    character.codeUnitAt(0) >= 0x61 && character.codeUnitAt(0) <= 0x7A;

bool _isDigit(String character) =>
    character.codeUnitAt(0) >= 0x30 && character.codeUnitAt(0) <= 0x39;

EnglishParseOutcome parseEnglishText(String lowercaseText) {
  final units = <EnglishUnit>[];
  var index = 0;
  var wordStartIndex = 0;
  var foundLetter = false;

  while (index < lowercaseText.length) {
    final character = lowercaseText[index];
    if (_wordSeparators.contains(character)) {
      units.add(EnglishWordBreakUnit(character));
      index++;
      wordStartIndex = index;
    } else if (_isDigit(character)) {
      units.add(LiteralUnit(character));
      index++;
    } else if (_isLowercaseLetter(character)) {
      foundLetter = true;
      index = _readEnglishUnit(lowercaseText, index, wordStartIndex, units);
    } else {
      return RejectedEnglishText(
          describeUnsupportedCharacter(lowercaseText.codeUnitAt(index), index));
    }
  }

  final hasContent = units.any((unit) => unit is! EnglishWordBreakUnit);
  if (!foundLetter && hasContent) {
    return const RejectedEnglishText('the input has no letters');
  }
  return ParsedEnglishText(units);
}

int _readEnglishUnit(
    String text, int index, int wordStartIndex, List<EnglishUnit> units) {
  if (index == wordStartIndex && text.startsWith('yu', index)) {
    units.add(const VowelUnit('yu'));
    return index + 2;
  }

  final vowelDigraph = _firstMatching(_vowelDigraphs, text, index);
  if (vowelDigraph != null) {
    final lastLetter = vowelDigraph[vowelDigraph.length - 1];
    final endsWithGlide = lastLetter == 'y' || lastLetter == 'w';
    final letterAfter = index + vowelDigraph.length < text.length
        ? text[index + vowelDigraph.length]
        : null;
    final followedByVowel =
        letterAfter != null && _plainVowels.contains(letterAfter);
    if (!(endsWithGlide && followedByVowel)) {
      units.add(VowelUnit(vowelDigraph));
      return index + vowelDigraph.length;
    }
  }

  final character = text[index];
  if (_plainVowels.contains(character)) {
    units.add(VowelUnit(character));
    return index + 1;
  }

  final consonantDigraph = _firstMatching(_consonantDigraphs, text, index);
  if (consonantDigraph != null) {
    units.add(ConsonantUnit(consonantDigraph));
    return index + consonantDigraph.length;
  }

  final atWordEnd =
      index + 1 >= text.length || _wordSeparators.contains(text[index + 1]);
  if (character == 'y' &&
      atWordEnd &&
      units.isNotEmpty &&
      units.last is ConsonantUnit) {
    units.add(const VowelUnit('y'));
    return index + 1;
  }

  final previous = units.isEmpty ? null : units.last;
  if (previous is ConsonantUnit &&
      !previous.isDoubled &&
      previous.letters == character) {
    units[units.length - 1] = ConsonantUnit(previous.letters, isDoubled: true);
  } else {
    units.add(ConsonantUnit(character));
  }
  return index + 1;
}

String? _firstMatching(List<String> candidates, String text, int index) {
  for (final candidate in candidates) {
    if (text.startsWith(candidate, index)) return candidate;
  }
  return null;
}
