/// Author: Zakaria Hossain
/// Description: English language definition, accented character mappings, and normalizers.
library;

import '../../core/language.dart';
import 'english_rules.dart';

final Map<String, String> _englishCanonicalSequences = {
  for (var unit = 0x0300; unit <= 0x036F; unit++) String.fromCharCode(unit): '',
  '’': "'",
  '‘': "'",
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
  'ø': 'o',
  'ł': 'l',
  'đ': 'd',
  'ð': 'd',
  'þ': 'th',
  ..._accentedLetters,
};

final Map<String, String> _accentedLetters = {
  for (final entry in const {
    'a': 'àáâãäåāăą',
    'c': 'çćĉċč',
    'd': 'ď',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'i': 'ìíîïĩīĭįı',
    'n': 'ñńņňŉ',
    'o': 'òóôõöōŏő',
    's': 'śŝşš',
    't': 'ţťŧ',
    'u': 'ùúûüũūŭůűų',
    'y': 'ýÿŷ',
    'z': 'źżž',
  }.entries)
    for (final accented in entry.value.split('')) accented: entry.key,
};

/// The English language definition.
final PhoneticLanguage englishLanguage = PhoneticLanguage(
  code: 'en',
  name: 'English',
  foldCase: true,
  rules: englishRules,
  canonicalSequences: _englishCanonicalSequences,
  marks: const {0x27, 0x2D, 0x2E},
);
