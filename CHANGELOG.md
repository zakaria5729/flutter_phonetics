## 0.2.0

- Added cross-language phonetic generation. `CrossLanguagePhonetics` (async) and
  `CrossLanguageEngine` (sync) take a Bangla or an English name and return two
  independent lists, Bangla spellings and English spellings, each built from how
  the name sounds. The list in the input's own script is what the existing
  engine returns.
- Added `PhoneticSearchOptions` and `CrossLanguageResult`.
- The generator can now start from pre-built slots. Existing `generate`,
  `similarity`, `matches` and `rank` results are unchanged.

## 0.1.3

- Added the live web demo link to the readme.

## 0.1.2

- Named the author, zakaria5729, in the readme.

## 0.1.1

- Added API documentation for the public classes, methods and fields.

## 0.1.0

- Initial release. `Phonetics` with `generate`, `generateWords`, `similarity`,
  `matches` and `rank`, running on an isolate or a web worker.
- Languages are plain `PhoneticLanguage` definitions. Bangla and English are
  built in (`BanglaPhonetics`, `EnglishPhonetics`), and a new language is one
  new folder.
- Rules can be limited to the start, the end or the inside of a word
  (`RulePosition`).
- Nothing throws: calls return records with a `PhoneticException? error`, and
  constructors keep problems in an `error` property.
- Cancellation with `PhoneticCancelToken`, `cancelAll()` and `dispose()`.
- `PhoneticExecutionMode`: `cancelPrevious` (default) or `queue`, changeable
  with `setExecutionMode`.
- Bangla rules: optional final `ো`, `ঞ্জ`/`ঞ্চ` against `নজ`/`নচ`, and independent
  vowel letters against vowel signs. `PhoneticRule(..., scoreOnly: true)` rules
  count when comparing words but never when generating spellings.
