/// Author: Zakaria Hossain
/// Description: Bangla-specific phonetic generator instance and configuration.
library;

import '../../phonetics.dart';
import 'bangla_language.dart';

class BanglaPhonetics extends Phonetics {
  BanglaPhonetics({
    super.rules,
    super.gapSimilarity,
    super.markGapSimilarity,
    super.unrelatedSimilarity,
    super.executionMode,
  }) : super(language: banglaLanguage);

  static final BanglaPhonetics instance = BanglaPhonetics();
}
