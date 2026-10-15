/// Author: Zakaria Hossain
/// Description: Rule model defining spelling substitutions, similarities, and positions.
library;

enum RulePosition {
  anywhere,
  wordStart,
  notWordStart,
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

class PhoneticRule {
  const PhoneticRule(
    this.group,
    this.similarity, {
    this.position = RulePosition.anywhere,
    this.scoreOnly = false,
  });

  final List<String> group;
  final double similarity;
  final RulePosition position;

  /// A score-only rule counts when comparing words (`similarity`, `matches`,
  /// `rank`) but is never used to build new spellings in `generate`.
  final bool scoreOnly;

  @override
  String toString() =>
      'PhoneticRule($group, $similarity, $position${scoreOnly ? ', scoreOnly' : ''})';
}
