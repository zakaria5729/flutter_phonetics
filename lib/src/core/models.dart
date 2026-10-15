/// Author: Zakaria Hossain
/// Description: Data models representing phonetic matches, scores, and letter changes.
library;

/// One letter or group of letters that was swapped to reach a variant.
class PhoneticChange {
  const PhoneticChange({
    required this.position,
    required this.from,
    required this.to,
    required this.similarity,
  });

  /// Where in the original word the swap happened.
  final int position;

  /// The spelling in the original word.
  final String from;

  /// The spelling used in the variant.
  final String to;

  /// How alike the two spellings sound, from 0 to 1.
  final double similarity;

  Map<String, Object> toJson() => {
        'position': position,
        'from': from,
        'to': to,
        'similarity': similarity,
      };

  @override
  String toString() => '$from→$to';

  @override
  bool operator ==(Object other) =>
      other is PhoneticChange &&
      other.position == position &&
      other.from == from &&
      other.to == to &&
      other.similarity == similarity;

  @override
  int get hashCode => Object.hash(position, from, to, similarity);
}

/// A spelling variant with its match percentage.
class PhoneticMatch {
  const PhoneticMatch(this.word, this.score,
      [this.changes = const <PhoneticChange>[]]);

  /// The variant spelling.
  final String word;

  /// How closely the variant sounds like the input, from 0 to 100.
  final double score;

  /// The swaps that turn the input into [word].
  final List<PhoneticChange> changes;

  Map<String, Object> toJson() => {
        'word': word,
        'score': score,
        'changes': [for (final change in changes) change.toJson()],
      };

  @override
  String toString() => '$word (${score.toStringAsFixed(2)}%)';

  @override
  bool operator ==(Object other) =>
      other is PhoneticMatch && other.word == word && other.score == score;

  @override
  int get hashCode => Object.hash(word, score);
}
