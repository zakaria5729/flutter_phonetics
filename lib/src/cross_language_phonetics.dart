import 'cancel.dart';
import 'core/language.dart';
import 'core/rules.dart';
import 'cross_language/cross_language_models.dart';
import 'errors.dart';
import 'execution_mode.dart';
import 'languages/bangla/bangla_language.dart';
import 'phonetic_request_runner.dart';
import 'protocol/protocol.dart';

class CrossLanguagePhonetics {
  CrossLanguagePhonetics({
    PhoneticRuleSet? banglaRules,
    double gapSimilarity = 0.5,
    double markGapSimilarity = 0.85,
    double unrelatedSimilarity = 0.4,
    PhoneticExecutionMode executionMode = PhoneticExecutionMode.cancelPrevious,
  }) : _runner = PhoneticRequestRunner.start(
          () => encodeCrossLanguageConfig(PhoneticEngine(
            language: banglaLanguage,
            rules: banglaRules,
            gapSimilarity: gapSimilarity,
            markGapSimilarity: markGapSimilarity,
            unrelatedSimilarity: unrelatedSimilarity,
          )),
          executionMode,
        );

  static final CrossLanguagePhonetics instance = CrossLanguagePhonetics();

  final PhoneticRequestRunner _runner;

  String get workerName => _runner.workerName;

  PhoneticExecutionMode get executionMode => _runner.executionMode;

  void setExecutionMode(PhoneticExecutionMode mode) {
    _runner.executionMode = mode;
  }

  Future<CrossLanguageResult> generate(
    String input, {
    Set<PhoneticLanguage>? languages,
    double minScore = 70,
    int? maxResults = 50,
    bool includeOriginal = true,
    int? maxChanges,
    PhoneticSearchOptions? banglaOptions,
    PhoneticSearchOptions? englishOptions,
    PhoneticCancelToken? cancelToken,
  }) async {
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

    final outcome = await _runner.run(
      () => crossGenerateRequest(
        input,
        wantsBangla: includesBangla(selectedLanguages),
        wantsEnglish: includesEnglish(selectedLanguages),
        banglaOptions: resolvedBanglaOptions,
        englishOptions: resolvedEnglishOptions,
      ),
      cancelToken,
      decodeCrossLanguageResult,
    );
    return outcome.value ??
        failedCrossLanguageResult(
            outcome.error ?? const PhoneticWorkerException('no result'));
  }

  void cancelAll() => _runner.cancelAll();

  Future<void> dispose() => _runner.dispose();
}
