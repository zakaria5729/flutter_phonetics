/// Author: Zakaria Hossain
/// Description: Rule model defining spelling substitutions, similarities, and positions.
library;

/// Where in a word a rule may be used.
enum RulePosition {
  /// At any place in the word.
  anywhere,

  /// Only at the start of the word.
  wordStart,

  /// Anywhere except the start of the word.
  notWordStart,

  /// Only at the end of the word.
  wordEnd;

  bool appliesTo({required bool atWordStart, required bool atWordEnd}) {
    switch (this) {
      case RulePosition.anywhere:
        return true;
      case RulePosition.wordStart:
        return atWordStart;
      case RulePosition.notWordStart:
        return !atWordStart;
      case RulePosition.wordEnd:
        return atWordEnd;
    }
  }
}

/// A group of spellings that sound alike.
///
/// Every spelling in [group] can replace any other, scored by [similarity].
class PhoneticRule {
  const PhoneticRule(
    this.group,
    this.similarity, {
    this.position = RulePosition.anywhere,
    this.scoreOnly = false,
  });

  /// The spellings that sound alike.
  final List<String> group;

  /// How alike the spellings sound, above 0 and up to 1.
  final double similarity;

  /// Where in a word the rule applies.
  final RulePosition position;

  /// A score-only rule counts when comparing words (`similarity`, `matches`,
  /// `rank`) but is never used to build new spellings in `generate`.
  final bool scoreOnly;

  @override
  String toString() =>
      'PhoneticRule($group, $similarity, $position${scoreOnly ? ', scoreOnly' : ''})';
}
