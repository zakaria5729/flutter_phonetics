import '../core/engine.dart';
import '../core/rules.dart';

class SpellingOptions {
  SpellingOptions._(this.reference, this.alternatives);

  factory SpellingOptions.of(
    String reference, [
    List<(String, double)> alternatives = const [],
  ]) {
    final bestSimilarityByText = <String, double>{};
    for (final (text, similarity) in alternatives) {
      if (text == reference) continue;
      final known = bestSimilarityByText[text];
      if (known == null || similarity > known) {
        bestSimilarityByText[text] = similarity;
      }
    }
    final sorted = [
      for (final entry in bestSimilarityByText.entries)
        PhoneticAlternative(entry.key, entry.value),
    ]..sort((a, b) {
        final bySimilarity = b.similarity.compareTo(a.similarity);
        return bySimilarity != 0 ? bySimilarity : a.text.compareTo(b.text);
      });
    return SpellingOptions._(reference, sorted);
  }

  final String reference;
  final List<PhoneticAlternative> alternatives;

  bool get hasAlternatives => alternatives.isNotEmpty;
}

sealed class SpellingPlan {
  const SpellingPlan();
}

final class ReadySpellingPlan extends SpellingPlan {
  const ReadySpellingPlan(this.referenceSpelling, this.slots);

  final String referenceSpelling;
  final List<SearchSlot> slots;
}

final class RejectedSpellingPlan extends SpellingPlan {
  const RejectedSpellingPlan(this.reason);

  final String reason;
}

class SpellingPlanBuilder {
  final StringBuffer _referenceBuffer = StringBuffer();
  final List<SearchSlot> _slots = [];
  int _nextSequence = 0;

  void appendFixed(String text) => _referenceBuffer.write(text);

  void appendChoice(SpellingOptions options) {
    final start = _referenceBuffer.length;
    _referenceBuffer.write(options.reference);
    if (options.hasAlternatives) {
      _slots.add(SearchSlot(
          start, options.reference, options.alternatives, _nextSequence++));
    }
  }

  ReadySpellingPlan build() => ReadySpellingPlan(
      _referenceBuffer.toString(), orderSlotsByConfidence(_slots));
}

String describeUnsupportedCharacter(int codeUnit, int position) {
  final hexCode = codeUnit.toRadixString(16).toUpperCase().padLeft(4, '0');
  return 'unsupported character U+$hexCode at position $position';
}
