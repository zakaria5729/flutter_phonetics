/// Author: Zakaria Hossain
/// Description: English-specific phonetic generator instance and configuration.
library;

import '../../phonetics.dart';
import 'english_language.dart';

class EnglishPhonetics extends Phonetics {
  EnglishPhonetics({
    super.rules,
    super.gapSimilarity,
    super.markGapSimilarity,
    super.unrelatedSimilarity,
    super.executionMode,
  }) : super(language: englishLanguage);

  static final EnglishPhonetics instance = EnglishPhonetics();
}
