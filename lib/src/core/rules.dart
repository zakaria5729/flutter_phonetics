/// Author: Zakaria Hossain
/// Description: Rule set indexing, retrieval, and validation for languages.
library;

import 'dart:math' as math;

import '../errors.dart';
import 'language.dart';
import 'phonetic_rule.dart';

class PhoneticAlternative {
  PhoneticAlternative(this.text, this.similarity)
      : logSimilarity = math.log(similarity);

  final String text;
  final double similarity;
  final double logSimilarity;

  @override
  String toString() => '$text($similarity)';
}

class PhoneticRuleSet {
  PhoneticRuleSet._(
      this.language,
      this._scoringAlternatives,
      this._generatingAlternatives,
      this.rules,
      this.longestSpellingLength,
      this._problems)
      : error = _problems.isEmpty
            ? null
            : PhoneticArgumentException(
                'invalid phonetic rules: ${_problems.join('; ')}');

  factory PhoneticRuleSet(Iterable<PhoneticRule> rules,
          {required PhoneticLanguage language}) =>
      _build(rules, language, const []);

  factory PhoneticRuleSet.fromJson(Object? json,
      {required PhoneticLanguage language}) {
    final rules = <PhoneticRule>[];
    final problems = <String>[];
    if (json is! List) {
      problems.add('rules must be a list');
    } else {
      for (final entry in json) {
        final rule = _ruleFromJson(entry);
        if (rule == null) {
          problems.add('malformed rule entry: $entry');
        } else {
          rules.add(rule);
        }
      }
    }
    return _build(rules, language, problems);
  }

  static PhoneticRule? _ruleFromJson(Object? entry) {
    if (entry is! List || entry.length < 3) return null;
    final similarity = entry[0];
    final positionIndex = entry[1];
    final scoreOnlyFlag = entry[2];
    if (similarity is! num || positionIndex is! int || scoreOnlyFlag is! int) {
      return null;
    }
    if (positionIndex < 0 || positionIndex >= RulePosition.values.length) {
      return null;
    }
    if (scoreOnlyFlag != 0 && scoreOnlyFlag != 1) return null;
    final spellings = <String>[];
    for (final spelling in entry.skip(3)) {
      if (spelling is! String) return null;
      spellings.add(spelling);
    }
    return PhoneticRule(
      spellings,
      similarity.toDouble(),
      position: RulePosition.values[positionIndex],
      scoreOnly: scoreOnlyFlag == 1,
    );
  }

  static PhoneticRuleSet _build(Iterable<PhoneticRule> rules,
      PhoneticLanguage language, List<String> earlierProblems) {
    final problems = [...earlierProblems];
    final scoringTargets = <String, Map<(String, RulePosition), double>>{};
    final generatingTargets = <String, Map<(String, RulePosition), double>>{};
    final validRules = <PhoneticRule>[];
    var longestSpelling = 1;

    for (final rule in rules) {
      final similarity = rule.similarity;
      if (similarity.isNaN || similarity <= 0 || similarity >= 1) {
        problems.add(
            'similarity must be greater than 0 and less than 1 (got $similarity for ${rule.group})');
        continue;
      }
      final group = <String>[];
      var hasEmptySpelling = false;
      for (final raw in rule.group) {
        final spelling = language.normalize(raw);
        if (spelling.isEmpty) {
          hasEmptySpelling = true;
        } else if (!group.contains(spelling)) {
          group.add(spelling);
        }
      }
      if (hasEmptySpelling) {
        problems.add('spellings must not be empty (in ${rule.group})');
        continue;
      }
      if (group.length < 2) {
        problems.add(
            'a rule needs at least two different spellings (got ${rule.group})');
        continue;
      }
      validRules.add(PhoneticRule(List.unmodifiable(group), similarity,
          position: rule.position, scoreOnly: rule.scoreOnly));

      for (final from in group) {
        longestSpelling = math.max(longestSpelling, from.length);
        for (final table in [
          scoringTargets,
          if (!rule.scoreOnly) generatingTargets,
        ]) {
          final targets = table.putIfAbsent(from, () => {});
          for (final to in group) {
            if (from == to) continue;
            final key = (to, rule.position);
            final existing = targets[key];
            if (existing == null || similarity > existing) {
              targets[key] = similarity;
            }
          }
        }
      }
    }

    return PhoneticRuleSet._(
        language,
        _compile(scoringTargets),
        _compile(generatingTargets),
        List.unmodifiable(validRules),
        longestSpelling,
        List.unmodifiable(problems));
  }

  static Map<String, List<List<PhoneticAlternative>>> _compile(
      Map<String, Map<(String, RulePosition), double>> targetsByFrom) {
    final compiled = <String, List<List<PhoneticAlternative>>>{};
    targetsByFrom.forEach((from, targets) {
      compiled[from] = [
        for (var context = 0; context < 4; context++)
          _alternativesForContext(targets,
              atWordStart: context & 1 != 0, atWordEnd: context & 2 != 0),
      ];
    });
    return compiled;
  }

  static List<PhoneticAlternative> _alternativesForContext(
    Map<(String, RulePosition), double> targets, {
    required bool atWordStart,
    required bool atWordEnd,
  }) {
    final best = <String, double>{};
    targets.forEach((key, similarity) {
      final (text, position) = key;
      if (!position.appliesTo(atWordStart: atWordStart, atWordEnd: atWordEnd)) {
        return;
      }
      final existing = best[text];
      if (existing == null || similarity > existing) best[text] = similarity;
    });
    final sorted = [
      for (final entry in best.entries)
        PhoneticAlternative(entry.key, entry.value),
    ]..sort((a, b) {
        final bySimilarity = b.similarity.compareTo(a.similarity);
        return bySimilarity != 0 ? bySimilarity : a.text.compareTo(b.text);
      });
    return List.unmodifiable(sorted);
  }

  static final Expando<PhoneticRuleSet> _defaults = Expando();

  static PhoneticRuleSet forLanguage(PhoneticLanguage language) =>
      _defaults[language] ??=
          PhoneticRuleSet(language.rules, language: language);

  final PhoneticLanguage language;
  final Map<String, List<List<PhoneticAlternative>>> _scoringAlternatives;
  final Map<String, List<List<PhoneticAlternative>>> _generatingAlternatives;
  final List<PhoneticRule> rules;
  final int longestSpellingLength;
  final List<String> _problems;
  final PhoneticArgumentException? error;

  String get languageCode => language.code;

  PhoneticRuleSet extend(Iterable<PhoneticRule> extraRules) =>
      _build([...rules, ...extraRules], language, _problems);

  bool hasRuleFor(String spelling) =>
      _scoringAlternatives.containsKey(spelling);

  List<PhoneticAlternative> alternativesFor(
    String spelling, {
    bool atWordStart = false,
    bool atWordEnd = false,
    bool generating = false,
  }) {
    final byContext =
        (generating ? _generatingAlternatives : _scoringAlternatives)[spelling];
    if (byContext == null) return const [];
    return byContext[(atWordStart ? 1 : 0) | (atWordEnd ? 2 : 0)];
  }

  List<Object> toJson() => [
        for (final rule in rules)
          [
            rule.similarity,
            rule.position.index,
            rule.scoreOnly ? 1 : 0,
            ...rule.group,
          ],
      ];
}

extension PhoneticLanguageRules on PhoneticLanguage {
  PhoneticRuleSet get defaultRuleSet => PhoneticRuleSet.forLanguage(this);
}
