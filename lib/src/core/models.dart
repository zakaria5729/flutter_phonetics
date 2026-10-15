/// Author: Zakaria Hossain
/// Description: Data models representing phonetic matches, scores, and letter changes.
library;

class PhoneticChange {
  const PhoneticChange({
    required this.position,
    required this.from,
    required this.to,
    required this.similarity,
  });

  final int position;
  final String from;
  final String to;
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

class PhoneticMatch {
  const PhoneticMatch(this.word, this.score,
      [this.changes = const <PhoneticChange>[]]);

  final String word;
  final double score;
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
