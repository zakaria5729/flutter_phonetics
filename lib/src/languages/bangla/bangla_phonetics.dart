/// Author: Zakaria Hossain
/// Description: Bangla-specific phonetic generator instance and configuration.
library;

import '../../phonetics.dart';
import 'bangla_language.dart';

/// Sound-alike spelling search for Bangla.
class BanglaPhonetics extends Phonetics {
  /// Creates a Bangla instance. See [Phonetics.new] for the settings.
  BanglaPhonetics({
    super.rules,
    super.gapSimilarity,
    super.markGapSimilarity,
    super.unrelatedSimilarity,
    super.executionMode,
  }) : super(language: banglaLanguage);

  /// A shared instance with the default settings.
  static final BanglaPhonetics instance = BanglaPhonetics();
}
