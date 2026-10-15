/// Author: Zakaria Hossain
/// Description: Language configuration, normalization settings, and character definitions.
library;

import '../errors.dart';
import 'phonetic_rule.dart';
import 'text_normalizer.dart';

class PhoneticLanguage {
  PhoneticLanguage({
    required String code,
    required String name,
    required List<PhoneticRule> rules,
    bool foldCase = false,
    Map<String, String> canonicalSequences = const {},
    Set<int> marks = const {},
  }) : this._(
          code: code,
          name: name,
          rules: rules,
          foldCase: foldCase,
          canonicalSequences: canonicalSequences,
          marks: marks,
          parseProblems: const [],
        );

  PhoneticLanguage._({
    required this.code,
    required this.name,
    required this.rules,
    required this.foldCase,
    required this.canonicalSequences,
    required this.marks,
    required List<String> parseProblems,
  }) : error = _combine([
          ...parseProblems,
          if (code.isEmpty) 'the language code must not be empty',
          if (canonicalSequences.keys.any((key) => key.isEmpty))
            'canonical sequences must not have an empty key',
        ]);

  factory PhoneticLanguage.fromJson(Object? json) {
    if (json is! Map) {
      return PhoneticLanguage._(
        code: '',
        name: '',
        rules: const [],
        foldCase: false,
        canonicalSequences: const {},
        marks: const {},
        parseProblems: const ['the language definition is missing'],
      );
    }
    final problems = <String>[];
    final sequences = <String, String>{};
    final sequenceList = json['sequences'];
    if (sequenceList is List) {
      for (final entry in sequenceList) {
        if (entry is List &&
            entry.length == 2 &&
            entry[0] is String &&
            entry[1] is String) {
          sequences[entry[0] as String] = entry[1] as String;
        } else {
          problems.add('malformed canonical sequence: $entry');
        }
      }
    } else if (sequenceList != null) {
      problems.add('sequences must be a list');
    }
    final marks = <int>{};
    final markList = json['marks'];
    if (markList is List) {
      for (final mark in markList) {
        if (mark is int) {
          marks.add(mark);
        } else {
          problems.add('malformed mark: $mark');
        }
      }
    } else if (markList != null) {
      problems.add('marks must be a list');
    }
    final code = json['code'];
    final name = json['name'];
    return PhoneticLanguage._(
      code: code is String ? code : '',
      name: name is String ? name : '',
      rules: const [],
      foldCase: json['foldCase'] == true,
      canonicalSequences: sequences,
      marks: marks,
      parseProblems: problems,
    );
  }

  final String code;
  final String name;
  final List<PhoneticRule> rules;
  final bool foldCase;
  final Map<String, String> canonicalSequences;
  final Set<int> marks;
  final PhoneticArgumentException? error;

  late final TextNormalizer normalizer = TextNormalizer(
    foldCase: foldCase,
    canonicalSequences: canonicalSequences,
    marks: marks,
  );

  String normalize(String text) => normalizer.normalize(text);

  Map<String, Object?> toJson() => {
        'code': code,
        'name': name,
        'foldCase': foldCase,
        'sequences': [
          for (final entry in canonicalSequences.entries)
            [entry.key, entry.value],
        ],
        'marks': marks.toList(),
      };

  @override
  String toString() => 'PhoneticLanguage($code)';

  static PhoneticArgumentException? _combine(List<String> problems) => problems
          .isEmpty
      ? null
      : PhoneticArgumentException('invalid language: ${problems.join('; ')}');
}
