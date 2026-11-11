import '../core/engine.dart';
import '../core/language.dart';
import '../core/models.dart';
import '../core/rules.dart';
import '../errors.dart';
import '../languages/bangla/bangla_language.dart';
import '../languages/english/english_language.dart';
import 'bangla_to_english_plan.dart';
import 'cross_language_job.dart';
import 'cross_language_models.dart';
import 'english_to_bangla_plan.dart';
import 'input_script.dart';
import 'spelling_plan.dart';

class CrossLanguageEngine {
  CrossLanguageEngine({
    PhoneticRuleSet? banglaRules,
    double gapSimilarity = 0.5,
    double markGapSimilarity = 0.85,
    double unrelatedSimilarity = 0.4,
  }) : this.fromBanglaEngine(PhoneticEngine(
          language: banglaLanguage,
          rules: banglaRules,
          gapSimilarity: gapSimilarity,
          markGapSimilarity: markGapSimilarity,
          unrelatedSimilarity: unrelatedSimilarity,
        ));

  CrossLanguageEngine.fromBanglaEngine(this._banglaEngine)
      : _englishEngine = PhoneticEngine(language: englishLanguage);

  final PhoneticEngine _banglaEngine;
  final PhoneticEngine _englishEngine;

  PhoneticArgumentException? get error => _banglaEngine.error;

  CrossLanguageResult generate(
    String input, {
    Set<PhoneticLanguage>? languages,
    double minScore = 70,
    int? maxResults = 50,
    bool includeOriginal = true,
    int? maxChanges,
    PhoneticSearchOptions? banglaOptions,
    PhoneticSearchOptions? englishOptions,
  }) {
    final sharedOptions = PhoneticSearchOptions(
      minScore: minScore,
      maxResults: maxResults,
      includeOriginal: includeOriginal,
      maxChanges: maxChanges,
    );
    final selectedLanguages = languages ?? bothSupportedLanguages;
    final resolvedBanglaOptions = banglaOptions ?? sharedOptions;
    final resolvedEnglishOptions = englishOptions ?? sharedOptions;
    final problem = crossLanguageArgumentError(
        selectedLanguages, resolvedBanglaOptions, resolvedEnglishOptions);
    if (problem != null) return failedCrossLanguageResult(problem);
    try {
      return createJob(
        input,
        wantsBangla: includesBangla(selectedLanguages),
        wantsEnglish: includesEnglish(selectedLanguages),
        banglaOptions: resolvedBanglaOptions,
        englishOptions: resolvedEnglishOptions,
      ).run();
    } catch (failure) {
      return failedCrossLanguageResult(PhoneticWorkerException('$failure'));
    }
  }

  PhoneticJob<CrossLanguageResult> createJob(
    String input, {
    required bool wantsBangla,
    required bool wantsEnglish,
    required PhoneticSearchOptions banglaOptions,
    required PhoneticSearchOptions englishOptions,
  }) {
    switch (detectInputScript(input)) {
      case InputScript.empty:
        return CrossLanguageJob(
          wantsBangla
              ? ResultSide.finishedWithNoMatches()
              : ResultSide.notRequested(),
          wantsEnglish
              ? ResultSide.finishedWithNoMatches()
              : ResultSide.notRequested(),
        );

      case InputScript.unsupported:
        final rejection = ResultSide.failed(const PhoneticArgumentException(
            'the input must be a Bangla or English name'));
        return CrossLanguageJob(
          wantsBangla ? rejection : ResultSide.notRequested(),
          wantsEnglish ? rejection : ResultSide.notRequested(),
        );

      case InputScript.bangla:
        return CrossLanguageJob(
          wantsBangla
              ? _createBanglaVariantsSide(input, banglaOptions)
              : ResultSide.notRequested(),
          wantsEnglish
              ? _createEnglishFromBanglaSide(input, englishOptions)
              : ResultSide.notRequested(),
        );

      case InputScript.latin:
        return CrossLanguageJob(
          wantsBangla
              ? _createBanglaFromEnglishSide(input, banglaOptions)
              : ResultSide.notRequested(),
          wantsEnglish
              ? _createEnglishVariantsSide(input, englishOptions)
              : ResultSide.notRequested(),
        );
    }
  }

  ResultSide _createBanglaVariantsSide(
      String input, PhoneticSearchOptions options) {
    final engineProblem = _banglaEngine.error;
    if (engineProblem != null) return ResultSide.failed(engineProblem);
    return _guardedSide(() => createGenerateJob(
          _banglaEngine,
          input,
          options.minScore,
          options.maxResults,
          options.includeOriginal,
          options.maxChanges,
        ));
  }

  ResultSide _createEnglishVariantsSide(
          String input, PhoneticSearchOptions options) =>
      _guardedSide(() => createGenerateJob(
            _englishEngine,
            input,
            options.minScore,
            options.maxResults,
            options.includeOriginal,
            options.maxChanges,
          ));

  ResultSide _createEnglishFromBanglaSide(
          String input, PhoneticSearchOptions options) =>
      _sideFromPlan(
        plan: () => planEnglishSpellings(banglaLanguage.normalize(input)),
        rejectionPrefix: 'cannot read the input as a Bangla name',
        options: options,
        renderWord: capitalizeEachWord,
      );

  ResultSide _createBanglaFromEnglishSide(
          String input, PhoneticSearchOptions options) =>
      _sideFromPlan(
        plan: () => planBanglaSpellings(englishLanguage.normalize(input)),
        rejectionPrefix: 'cannot read the input as an English name',
        options: options,
        renderWord: (word) => word,
      );

  ResultSide _sideFromPlan({
    required SpellingPlan Function() plan,
    required String rejectionPrefix,
    required PhoneticSearchOptions options,
    required String Function(String word) renderWord,
  }) {
    try {
      switch (plan()) {
        case RejectedSpellingPlan(:final reason):
          return ResultSide.failed(
              PhoneticArgumentException('$rejectionPrefix: $reason'));
        case ReadySpellingPlan(:final referenceSpelling, :final slots):
          return ResultSide.running(GenerateJob(
            referenceSpelling: referenceSpelling,
            slots: slots,
            renderWord: renderWord,
            minScore: options.minScore,
            maxResults: options.maxResults,
            outputLengthBasis: referenceSpelling.length,
            includeOriginal: true,
            maxChanges: options.maxChanges,
          ));
      }
    } catch (failure) {
      return ResultSide.failed(PhoneticWorkerException('$failure'));
    }
  }

  ResultSide _guardedSide(PhoneticJob<List<PhoneticMatch>> Function() create) {
    try {
      return ResultSide.running(create());
    } catch (failure) {
      return ResultSide.failed(PhoneticWorkerException('$failure'));
    }
  }
}
