import 'bangla_parser.dart';
import 'english_spelling_options.dart';
import 'inherent_vowel_rules.dart';
import 'spelling_plan.dart';

SpellingPlan planEnglishSpellings(String normalizedBanglaText) {
  if (normalizedBanglaText.isEmpty) {
    return const ReadySpellingPlan('', []);
  }

  final outcome = parseBanglaText(normalizedBanglaText);
  if (outcome is RejectedBanglaText) {
    return RejectedSpellingPlan(outcome.reason);
  }
  final tokens = (outcome as ParsedBanglaText).tokens;

  final planBuilder = SpellingPlanBuilder();
  final wordPlanner = _BanglaToEnglishWordPlanner(planBuilder);
  final currentWord = <BanglaToken>[];
  for (final token in tokens) {
    if (token is WordBreakToken) {
      wordPlanner.appendWord(currentWord);
      currentWord.clear();
      planBuilder.appendFixed(token.text);
    } else {
      currentWord.add(token);
    }
  }
  wordPlanner.appendWord(currentWord);
  return planBuilder.build();
}

String capitalizeEachWord(String text) {
  final buffer = StringBuffer();
  var atWordStart = true;
  for (var index = 0; index < text.length; index++) {
    final character = text[index];
    buffer.write(atWordStart ? character.toUpperCase() : character);
    atWordStart = character == ' ' || character == '-';
  }
  return buffer.toString();
}

class _BanglaToEnglishWordPlanner {
  _BanglaToEnglishWordPlanner(this._planBuilder);

  final SpellingPlanBuilder _planBuilder;

  void appendWord(List<BanglaToken> wordTokens) {
    if (wordTokens.isEmpty) return;
    final inherentVowelFates = resolveInherentVowelFates(wordTokens);
    var consonantsAlreadySpokenInNextGroup = 0;
    var previousTokenEndedWithVowel = false;
    var indexOfVowelAlreadySpoken = -1;

    for (var index = 0; index < wordTokens.length; index++) {
      if (index == indexOfVowelAlreadySpoken) continue;
      final token = wordTokens[index];
      final atWordStart = index == 0;
      final atWordEnd = index == wordTokens.length - 1;
      final followingToken =
          index + 1 < wordTokens.length ? wordTokens[index + 1] : null;

      switch (token) {
        case LiteralTextToken():
          _planBuilder.appendFixed(token.text);
          previousTokenEndedWithVowel = false;

        case NasalMarkToken():
          _planBuilder
              .appendChoice(EnglishSpellingOptions.forNasalMark(token.mark));
          previousTokenEndedWithVowel = false;

        case IndependentVowelToken():
          if (_startsWithWa(token, atWordStart, followingToken)) {
            _planBuilder.appendChoice(EnglishSpellingOptions.forWordStartWa());
            consonantsAlreadySpokenInNextGroup = 1;
          } else if (_isIUVowelPair(token, followingToken)) {
            _planBuilder.appendChoice(EnglishSpellingOptions.forYuVowelPair());
            indexOfVowelAlreadySpoken = index + 1;
          } else {
            _planBuilder.appendChoice(EnglishSpellingOptions.forVowel(
                _soundOfIndependentVowel(token.letter),
                atWordEnd: atWordEnd));
          }
          previousTokenEndedWithVowel = true;

        case ConsonantGroupToken():
          final consonants = token.consonants
              .skip(consonantsAlreadySpokenInNextGroup)
              .toList();
          final startsAtWordStart =
              atWordStart && consonantsAlreadySpokenInNextGroup == 0;
          consonantsAlreadySpokenInNextGroup = 0;
          final inherentVowelFate = inherentVowelFates[index];

          final mergesWithNextGroup =
              inherentVowelFate == InherentVowelFate.deletedInsideWord &&
                  consonants.length == 1 &&
                  followingToken is ConsonantGroupToken &&
                  followingToken.consonants.first == consonants[0];

          if (mergesWithNextGroup) {
            _planBuilder.appendChoice(EnglishSpellingOptions.geminated(
                EnglishSpellingOptions.forConsonant(consonants[0])));
            consonantsAlreadySpokenInNextGroup = 1;
          } else {
            _appendConsonants(
                consonants, startsAtWordStart, previousTokenEndedWithVowel);
            _appendVowelOfGroup(token, inherentVowelFate, atWordEnd);
          }
          previousTokenEndedWithVowel = token.vowelSign != null;

        case WordBreakToken():
          break;
      }
    }
  }

  bool _startsWithWa(IndependentVowelToken vowel, bool atWordStart,
          BanglaToken? followingToken) =>
      vowel.letter == 'ও' &&
      atWordStart &&
      followingToken is ConsonantGroupToken &&
      followingToken.vowelSign != null &&
      followingToken.consonants.first == yaWithDot;

  bool _isIUVowelPair(
          IndependentVowelToken vowel, BanglaToken? followingToken) =>
      (vowel.letter == 'ই' || vowel.letter == 'ঈ') &&
      followingToken is IndependentVowelToken &&
      (followingToken.letter == 'উ' || followingToken.letter == 'ঊ');

  void _appendConsonants(List<String> consonants, bool startsAtWordStart,
      bool previousTokenEndedWithVowel) {
    var position = 0;
    while (position < consonants.length) {
      final current = consonants[position];
      final following =
          position + 1 < consonants.length ? consonants[position + 1] : null;
      final atWordStart = startsAtWordStart && position == 0;
      final clusterOptions = following == null
          ? null
          : EnglishSpellingOptions.forCluster(current, following,
              atWordStart: atWordStart);
      final phalaOptions =
          position > 0 ? EnglishSpellingOptions.forPhala(current) : null;

      if (following != null && following == current) {
        _planBuilder.appendChoice(EnglishSpellingOptions.geminated(
            EnglishSpellingOptions.forConsonant(current)));
        position += 2;
      } else if (clusterOptions != null) {
        _planBuilder.appendChoice(clusterOptions);
        position += 2;
      } else if (phalaOptions != null) {
        _planBuilder.appendChoice(phalaOptions);
        position++;
      } else if (current == 'ঙ' &&
          following != null &&
          EnglishSpellingOptions.isVelar(following)) {
        _planBuilder.appendChoice(
            EnglishSpellingOptions.forNasalConsonantBeforeVelar());
        position++;
      } else if (current == yaWithDot &&
          position == 0 &&
          previousTokenEndedWithVowel) {
        _planBuilder.appendChoice(EnglishSpellingOptions.forYaAfterVowel());
        position++;
      } else {
        _planBuilder.appendChoice(EnglishSpellingOptions.forConsonant(current));
        position++;
      }
    }
  }

  void _appendVowelOfGroup(ConsonantGroupToken group,
      InherentVowelFate? inherentVowelFate, bool atWordEnd) {
    final sign = group.vowelSign;
    if (sign != null) {
      _planBuilder.appendChoice(EnglishSpellingOptions.forVowel(
          _soundOfVowelSign(sign),
          atWordEnd: atWordEnd));
      return;
    }
    if (inherentVowelFate == null) return;
    final options = EnglishSpellingOptions.forInherentVowel(inherentVowelFate);
    if (options != null) _planBuilder.appendChoice(options);
  }

  VowelSound _soundOfIndependentVowel(String letter) => switch (letter) {
        'আ' => VowelSound.a,
        'ই' || 'ঈ' => VowelSound.i,
        'উ' || 'ঊ' => VowelSound.u,
        'ঋ' => VowelSound.ri,
        'এ' => VowelSound.e,
        'ঐ' => VowelSound.oi,
        'ও' => VowelSound.o,
        'ঔ' => VowelSound.ou,
        _ => VowelSound.openO,
      };

  VowelSound _soundOfVowelSign(String sign) => switch (sign) {
        '\u09BE' => VowelSound.a,
        '\u09BF' || '\u09C0' => VowelSound.i,
        '\u09C1' || '\u09C2' => VowelSound.u,
        '\u09C3' => VowelSound.ri,
        '\u09C7' => VowelSound.e,
        '\u09C8' => VowelSound.oi,
        '\u09CB' => VowelSound.o,
        _ => VowelSound.ou,
      };
}
