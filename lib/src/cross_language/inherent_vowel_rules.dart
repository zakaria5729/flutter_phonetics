import 'bangla_parser.dart';

enum InherentVowelFate {
  realizedAtWordStart,
  realizedInsideWord,
  realizedAtWordEnd,
  deletedInsideWord,
  deletedAtWordEnd;

  bool get isDeleted =>
      this == InherentVowelFate.deletedInsideWord ||
      this == InherentVowelFate.deletedAtWordEnd;
}

Map<int, InherentVowelFate> resolveInherentVowelFates(
    List<BanglaToken> wordTokens) {
  final nucleusIndices = [
    for (var index = 0; index < wordTokens.length; index++)
      if (_isSyllableNucleus(wordTokens[index])) index,
  ];
  final fates = <int, InherentVowelFate>{};
  final realizedByNucleusPosition =
      List<bool>.filled(nucleusIndices.length, true);

  for (var position = nucleusIndices.length - 1; position >= 0; position--) {
    final tokenIndex = nucleusIndices[position];
    final token = wordTokens[tokenIndex];
    if (token is! ConsonantGroupToken || !token.hasInherentVowel) continue;

    final isFirstNucleus = position == 0;
    final isLastNucleus = position == nucleusIndices.length - 1;
    final needsVowelBeforeNasalMark = tokenIndex + 1 < wordTokens.length &&
        wordTokens[tokenIndex + 1] is NasalMarkToken;

    final InherentVowelFate fate;
    if (isFirstNucleus) {
      fate = InherentVowelFate.realizedAtWordStart;
    } else if (isLastNucleus && needsVowelBeforeNasalMark) {
      fate = InherentVowelFate.realizedInsideWord;
    } else if (isLastNucleus && token.isConjunct) {
      fate = InherentVowelFate.realizedAtWordEnd;
    } else if (isLastNucleus) {
      fate = InherentVowelFate.deletedAtWordEnd;
    } else if (needsVowelBeforeNasalMark || token.isConjunct) {
      fate = InherentVowelFate.realizedInsideWord;
    } else if (realizedByNucleusPosition[position + 1]) {
      fate = InherentVowelFate.deletedInsideWord;
    } else {
      fate = InherentVowelFate.realizedInsideWord;
    }

    fates[tokenIndex] = fate;
    realizedByNucleusPosition[position] = !fate.isDeleted;
  }
  return fates;
}

bool _isSyllableNucleus(BanglaToken token) => switch (token) {
      IndependentVowelToken() => true,
      ConsonantGroupToken(:final endsWithHasanta) => !endsWithHasanta,
      _ => false,
    };
