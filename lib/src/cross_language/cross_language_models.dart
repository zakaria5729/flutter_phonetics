import '../core/language.dart';
import '../core/validation.dart';
import '../errors.dart';
import '../languages/bangla/bangla_language.dart';
import '../languages/english/english_language.dart';
import '../results.dart';

class PhoneticSearchOptions {
  const PhoneticSearchOptions({
    this.minScore = 70,
    this.maxResults = 50,
    this.includeOriginal = true,
    this.maxChanges,
  });

  final double minScore;
  final int? maxResults;
  final bool includeOriginal;
  final int? maxChanges;
}

class CrossLanguageResult {
  const CrossLanguageResult({required this.bangla, required this.english});

  final PhoneticMatchesResult bangla;
  final PhoneticMatchesResult english;

  PhoneticException? get error => bangla.error ?? english.error;

  PhoneticMatchesResult? forLanguage(PhoneticLanguage language) =>
      switch (language.code) {
        'bn' => bangla,
        'en' => english,
        _ => null,
      };
}

Set<PhoneticLanguage> get bothSupportedLanguages =>
    {banglaLanguage, englishLanguage};

bool includesBangla(Set<PhoneticLanguage> languages) =>
    languages.any((language) => language.code == banglaLanguage.code);

bool includesEnglish(Set<PhoneticLanguage> languages) =>
    languages.any((language) => language.code == englishLanguage.code);

PhoneticArgumentException? crossLanguageSelectionError(
    Set<PhoneticLanguage> languages) {
  if (languages.isEmpty) {
    return const PhoneticArgumentException('languages must not be empty');
  }
  for (final language in languages) {
    if (language.code != banglaLanguage.code &&
        language.code != englishLanguage.code) {
      return PhoneticArgumentException(
          'cross-language generation does not support the language '
          '"${language.code}"');
    }
  }
  return null;
}

PhoneticArgumentException? crossLanguageOptionsError({
  required bool wantsBangla,
  required bool wantsEnglish,
  required PhoneticSearchOptions banglaOptions,
  required PhoneticSearchOptions englishOptions,
}) {
  if (wantsBangla) {
    final problem = _searchOptionsError(banglaOptions);
    if (problem != null) {
      return PhoneticArgumentException('Bangla options: ${problem.message}');
    }
  }
  if (wantsEnglish) {
    final problem = _searchOptionsError(englishOptions);
    if (problem != null) {
      return PhoneticArgumentException('English options: ${problem.message}');
    }
  }
  return null;
}

PhoneticArgumentException? crossLanguageArgumentError(
  Set<PhoneticLanguage> languages,
  PhoneticSearchOptions banglaOptions,
  PhoneticSearchOptions englishOptions,
) =>
    crossLanguageSelectionError(languages) ??
    crossLanguageOptionsError(
      wantsBangla: includesBangla(languages),
      wantsEnglish: includesEnglish(languages),
      banglaOptions: banglaOptions,
      englishOptions: englishOptions,
    );

PhoneticArgumentException? _searchOptionsError(PhoneticSearchOptions options) =>
    generateArgumentError(
        options.minScore, options.maxResults, options.maxChanges);

CrossLanguageResult failedCrossLanguageResult(PhoneticException error) =>
    CrossLanguageResult(
      bangla: (matches: const [], error: error),
      english: (matches: const [], error: error),
    );
