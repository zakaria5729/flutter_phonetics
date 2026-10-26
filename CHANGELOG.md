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
