/// Author: Zakaria Hossain
/// Description: English-specific phonetic generator instance and configuration.
library;

import '../../phonetics.dart';
import 'english_language.dart';

/// Sound-alike spelling search for English.
class EnglishPhonetics extends Phonetics {
  /// Creates an English instance. See [Phonetics.new] for the settings.
  EnglishPhonetics({
    super.rules,
    super.gapSimilarity,
    super.markGapSimilarity,
    super.unrelatedSimilarity,
    super.executionMode,
  }) : super(language: englishLanguage);

  /// A shared instance with the default settings.
  static final EnglishPhonetics instance = EnglishPhonetics();
}
