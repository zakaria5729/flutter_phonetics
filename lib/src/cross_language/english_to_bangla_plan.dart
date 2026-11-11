import 'bangla_spelling_options.dart';
import 'english_tokenizer.dart';
import 'spelling_plan.dart';

SpellingPlan planBanglaSpellings(String lowercaseEnglishText) {
  if (lowercaseEnglishText.isEmpty) {
    return const ReadySpellingPlan('', []);
  }

  final outcome = parseEnglishText(lowercaseEnglishText);
  if (outcome is RejectedEnglishText) {
    return RejectedSpellingPlan(outcome.reason);
  }
  final units = (outcome as ParsedEnglishText).units;

  final planBuilder = SpellingPlanBuilder();
  final currentWord = <EnglishUnit>[];
  for (final unit in units) {
    if (unit is EnglishWordBreakUnit) {
      _appendEnglishWord(planBuilder, currentWord);
      currentWord.clear();
      planBuilder.appendFixed(unit.text);
    } else {
      currentWord.add(unit);
    }
  }
  _appendEnglishWord(planBuilder, currentWord);
  return planBuilder.build();
}

void _appendEnglishWord(
    SpellingPlanBuilder planBuilder, List<EnglishUnit> wordUnits) {
  ConsonantUnit? previousConsonant;
  var previousConsonantIsAtWordStart = false;
  var previousWasVowelOrStart = true;

  for (var index = 0; index < wordUnits.length; index++) {
    final unit = wordUnits[index];
    final following =
        index + 1 < wordUnits.length ? wordUnits[index + 1] : null;

    switch (unit) {
      case LiteralUnit():
        planBuilder.appendFixed(unit.text);
        previousConsonant = null;
        previousWasVowelOrStart = true;

      case VowelUnit():
        final atWordEnd = index == wordUnits.length - 1;
        final beforeNasalNg = following is ConsonantUnit &&
            BanglaSpellingOptions.isNasalGroup(following.letters);
        planBuilder.appendChoice(BanglaSpellingOptions.forVowel(
          unit.letters,
          afterConsonant: previousConsonant != null,
          atWordEnd: atWordEnd,
          beforeNasalNg: beforeNasalNg,
        ));
        previousConsonant = null;
        previousWasVowelOrStart = true;

      case ConsonantUnit():
        final previous = previousConsonant;
        if (previous != null &&
            !BanglaSpellingOptions.isNasalGroup(previous.letters) &&
            !BanglaSpellingOptions.isNasalGroup(unit.letters)) {
          planBuilder.appendChoice(BanglaSpellingOptions.forConjunctJoin(
            previous.letters,
            unit.letters,
            firstIsAtWordStart: previousConsonantIsAtWordStart,
          ));
        }
        planBuilder.appendChoice(BanglaSpellingOptions.forConsonant(
          unit.letters,
          isDoubled: unit.isDoubled,
          atWordStart: index == 0,
          nextIsVowel: following is VowelUnit,
          nextVowelLetters: following is VowelUnit ? following.letters : null,
          followsWordInitialS:
              previous?.letters == 's' && previousConsonantIsAtWordStart,
        ));
        previousConsonantIsAtWordStart =
            previous == null && previousWasVowelOrStart && index == 0;
        previousConsonant = unit;
        previousWasVowelOrStart = false;

      case EnglishWordBreakUnit():
        break;
    }
  }
}
