/// Author: Zakaria Hossain
/// Description: Bangla language definition, diacritics, and normalization rules.
library;

import '../../core/language.dart';
import 'bangla_rules.dart';

// Escapes on purpose: ড় (U+09DC) and ড + nukta (U+09A1 U+09BC) look identical.
const Map<String, String> _banglaCanonicalSequences = {
  '\u09A1\u09BC': '\u09DC',
  '\u09A2\u09BC': '\u09DD',
  '\u09AF\u09BC': '\u09DF',
  '\u09A4\u09CD\u200D': '\u09CE',
  '\u09C7\u09BE': '\u09CB',
  '\u09C7\u09D7': '\u09CC',
};

const Set<int> _banglaMarks = {
  0x09CD,
  0x0981,
  0x09BC,
  0x0983,
  0x200C,
  0x200D,
};

final PhoneticLanguage banglaLanguage = PhoneticLanguage(
  code: 'bn',
  name: 'Bangla',
  rules: banglaRules,
  canonicalSequences: _banglaCanonicalSequences,
  marks: _banglaMarks,
);
