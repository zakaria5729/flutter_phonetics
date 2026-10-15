/// Author: Zakaria Hossain
/// Description: Parameter validation and range checking for phonetic requests.
library;

import '../errors.dart';

PhoneticArgumentException? minScoreError(double minScore) {
  if (minScore.isNaN || minScore < 0 || minScore > 100) {
    return PhoneticArgumentException(
        'minScore must be between 0 and 100 (got $minScore)');
  }
  return null;
}

PhoneticArgumentException? generateArgumentError(
    double minScore, int? maxResults, int? maxChanges) {
  final minScoreProblem = minScoreError(minScore);
  if (minScoreProblem != null) return minScoreProblem;
  if (maxResults != null && maxResults < 1) {
    return PhoneticArgumentException(
        'maxResults must be at least 1 (got $maxResults)');
  }
  if (maxChanges != null && maxChanges < 0) {
    return PhoneticArgumentException(
        'maxChanges must not be negative (got $maxChanges)');
  }
  return null;
}

PhoneticArgumentException? rankArgumentError(double minScore, int? limit) {
  final minScoreProblem = minScoreError(minScore);
  if (minScoreProblem != null) return minScoreProblem;
  if (limit != null && limit < 1) {
    return PhoneticArgumentException('limit must be at least 1 (got $limit)');
  }
  return null;
}
