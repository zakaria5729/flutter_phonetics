/// Author: Zakaria Hossain
/// Description: Result type definitions for phonetic operations and matches.
library;

import 'core/models.dart';
import 'errors.dart';

typedef PhoneticMatchesResult = ({
  List<PhoneticMatch> matches,
  PhoneticException? error,
});

typedef PhoneticWordsResult = ({
  List<String> words,
  PhoneticException? error,
});

typedef PhoneticSimilarityResult = ({
  double score,
  PhoneticException? error,
});

typedef PhoneticMatchCheckResult = ({
  bool isMatch,
  PhoneticException? error,
});
