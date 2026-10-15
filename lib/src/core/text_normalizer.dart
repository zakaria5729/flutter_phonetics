/// Author: Zakaria Hossain
/// Description: Text normalization, case folding, and canonical sequence mapping.
library;

import 'dart:typed_data';

const _codeUnitCount = 0x10000;

enum LetterCase { unchanged, lower, title, upper }

class TextNormalizer {
  TextNormalizer({
    required this.foldCase,
    required Map<String, String> canonicalSequences,
    required Set<int> marks,
  })  : _sequencesByFirstUnit = _groupByFirstUnit(canonicalSequences),
        _sequenceStarts = Uint8List(_codeUnitCount),
        _markTable = Uint8List(_codeUnitCount) {
    for (final unit in _sequencesByFirstUnit.keys) {
      _sequenceStarts[unit] = 1;
    }
    for (final mark in marks) {
      if (mark >= 0 && mark < _codeUnitCount) _markTable[mark] = 1;
    }
  }

  final bool foldCase;
  final Map<int, List<MapEntry<String, String>>> _sequencesByFirstUnit;
  final Uint8List _sequenceStarts;
  final Uint8List _markTable;

  bool isMark(int codeUnit) =>
      codeUnit >= 0 && codeUnit < _codeUnitCount && _markTable[codeUnit] == 1;

  String normalize(String input) {
    var text = input.trim();
    if (text.isEmpty) return text;
    if (foldCase && _hasUppercaseCandidate(text)) text = text.toLowerCase();
    text = _replaceSequences(text);
    return _hasIrregularWhitespace(text)
        ? text.replaceAll(_whitespaceRuns, ' ')
        : text;
  }

  LetterCase detectCase(String original) {
    if (!foldCase) return LetterCase.unchanged;
    var hasUpper = false;
    var hasLower = false;
    var everyWordStartsUpper = true;
    var atWordStart = true;
    for (final rune in original.runes) {
      final letter = String.fromCharCode(rune);
      if (letter.trim().isEmpty) {
        atWordStart = true;
        continue;
      }
      final isUpper = _isUpperLetter(letter);
      if (isUpper) hasUpper = true;
      if (_isLowerLetter(letter)) hasLower = true;
      if (atWordStart && !isUpper) everyWordStartsUpper = false;
      atWordStart = false;
    }
    if (!hasUpper && !hasLower) return LetterCase.unchanged;
    if (!hasLower) return LetterCase.upper;
    if (!hasUpper) return LetterCase.lower;
    return everyWordStartsUpper ? LetterCase.title : LetterCase.lower;
  }

  String applyCase(String text, LetterCase letterCase) {
    switch (letterCase) {
      case LetterCase.unchanged:
      case LetterCase.lower:
        return text;
      case LetterCase.upper:
        return text.toUpperCase();
      case LetterCase.title:
        return text
            .split(' ')
            .map((word) =>
                word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  String _replaceSequences(String text) {
    if (_sequencesByFirstUnit.isEmpty) return text;
    StringBuffer? output;
    var copiedUpTo = 0;
    var index = 0;
    while (index < text.length) {
      final unit = text.codeUnitAt(index);
      if (_sequenceStarts[unit] == 0) {
        index++;
        continue;
      }
      var replaced = false;
      for (final sequence in _sequencesByFirstUnit[unit]!) {
        if (text.startsWith(sequence.key, index)) {
          (output ??= StringBuffer())
            ..write(text.substring(copiedUpTo, index))
            ..write(sequence.value);
          index += sequence.key.length;
          copiedUpTo = index;
          replaced = true;
          break;
        }
      }
      if (!replaced) index++;
    }
    if (output == null) return text;
    return (output..write(text.substring(copiedUpTo))).toString();
  }

  static Map<int, List<MapEntry<String, String>>> _groupByFirstUnit(
      Map<String, String> sequences) {
    final grouped = <int, List<MapEntry<String, String>>>{};
    for (final entry in sequences.entries) {
      if (entry.key.isEmpty) continue;
      grouped.putIfAbsent(entry.key.codeUnitAt(0), () => []).add(entry);
    }
    for (final entries in grouped.values) {
      entries.sort((a, b) => b.key.length.compareTo(a.key.length));
    }
    return grouped;
  }
}

final RegExp _whitespaceRuns = RegExp(r'\s+');

// Letters whose case change is not one to one (such as ß) count as neither
// upper nor lower, because the Dart VM and JavaScript disagree about them.
bool _isUpperLetter(String letter) =>
    letter.toLowerCase() != letter &&
    letter.toLowerCase().runes.length == 1 &&
    letter.toUpperCase() == letter;

bool _isLowerLetter(String letter) =>
    letter.toUpperCase() != letter &&
    letter.toUpperCase().runes.length == 1 &&
    letter.toLowerCase() == letter;

bool _hasUppercaseCandidate(String text) {
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if ((unit >= 0x41 && unit <= 0x5A) || unit >= 0x80) return true;
  }
  return false;
}

bool _hasIrregularWhitespace(String text) {
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x20) {
      if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x20) return true;
    } else if (unit < 0x20 ||
        unit == 0xA0 ||
        unit == 0x1680 ||
        (unit >= 0x2000 && unit <= 0x200A) ||
        unit == 0x2028 ||
        unit == 0x2029 ||
        unit == 0x202F ||
        unit == 0x205F ||
        unit == 0x3000 ||
        unit == 0xFEFF) {
      return true;
    }
  }
  return false;
}
