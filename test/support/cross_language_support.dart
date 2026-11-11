import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:test/test.dart';

final CrossLanguageEngine crossLanguageEngine = CrossLanguageEngine();
final Set<PhoneticLanguage> englishOnly = {englishLanguage};
final Set<PhoneticLanguage> banglaOnly = {banglaLanguage};
final Set<PhoneticLanguage> bothLanguages = {banglaLanguage, englishLanguage};

List<PhoneticMatch> englishMatches(
  String name, {
  double minScore = 70,
  int? maxResults = 300,
  int? maxChanges,
}) {
  final result = crossLanguageEngine.generate(
    name,
    languages: englishOnly,
    minScore: minScore,
    maxResults: maxResults,
    maxChanges: maxChanges,
  );
  expect(result.error, isNull, reason: 'unexpected error for $name');
  return result.english.matches;
}

List<String> englishWords(String name, {double minScore = 70}) => [
      for (final match in englishMatches(name, minScore: minScore)) match.word,
    ];

List<PhoneticMatch> banglaMatches(
  String name, {
  double minScore = 70,
  int? maxResults = 300,
  int? maxChanges,
}) {
  final result = crossLanguageEngine.generate(
    name,
    languages: banglaOnly,
    minScore: minScore,
    maxResults: maxResults,
    maxChanges: maxChanges,
  );
  expect(result.error, isNull, reason: 'unexpected error for $name');
  return result.bangla.matches;
}

List<String> banglaWords(String name, {double minScore = 70}) => [
      for (final match in banglaMatches(name, minScore: minScore)) match.word,
    ];

String normalizedBangla(String text) => banglaLanguage.normalize(text);

List<double> sortedDescending(Iterable<double> values) =>
    values.toList()..sort((a, b) => b.compareTo(a));
