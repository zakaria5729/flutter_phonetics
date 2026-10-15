/// Author: Zakaria Hossain
/// Description: Main entry point exporting the public API of flutter_phonetics.
library;

export 'src/cancel.dart' show PhoneticCancelToken;
export 'src/core/engine.dart' show PhoneticEngine;
export 'src/core/language.dart' show PhoneticLanguage;
export 'src/core/models.dart' show PhoneticChange, PhoneticMatch;
export 'src/core/phonetic_rule.dart' show PhoneticRule, RulePosition;
export 'src/core/rules.dart'
    show PhoneticAlternative, PhoneticLanguageRules, PhoneticRuleSet;
export 'src/errors.dart'
    show
        PhoneticArgumentException,
        PhoneticCancelledException,
        PhoneticDisposedException,
        PhoneticException,
        PhoneticWorkerException;
export 'src/execution_mode.dart' show PhoneticExecutionMode;
export 'src/languages/bangla/bangla_language.dart' show banglaLanguage;
export 'src/languages/bangla/bangla_phonetics.dart' show BanglaPhonetics;
export 'src/languages/bangla/bangla_rules.dart' show banglaRules;
export 'src/languages/english/english_language.dart' show englishLanguage;
export 'src/languages/english/english_phonetics.dart' show EnglishPhonetics;
export 'src/languages/english/english_rules.dart' show englishRules;
export 'src/phonetics.dart' show Phonetics;
export 'src/results.dart'
    show
        PhoneticMatchCheckResult,
        PhoneticMatchesResult,
        PhoneticSimilarityResult,
        PhoneticWordsResult;
