/// Author: Zakaria Hossain
/// Description: Result type definitions for phonetic operations and matches.
library;

import 'core/models.dart';
import 'errors.dart';

/// Matches with their scores, plus an error if the request failed.
typedef PhoneticMatchesResult = ({
  List<PhoneticMatch> matches,
  PhoneticException? error,
});

/// Spellings only, plus an error if the request failed.
typedef PhoneticWordsResult = ({
  List<String> words,
  PhoneticException? error,
});

/// A similarity score from 0 to 100, plus an error if the request failed.
typedef PhoneticSimilarityResult = ({
  double score,
  PhoneticException? error,
});

/// Whether two spellings match, plus an error if the request failed.
typedef PhoneticMatchCheckResult = ({
  bool isMatch,
  PhoneticException? error,
});
