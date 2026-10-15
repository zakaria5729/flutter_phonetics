# flutter_phonetics

Finds sound-alike spellings of Bangla and English words, with a match percentage.
The work runs on a background thread on every Flutter platform, so the UI never
waits for it.

```dart
// Bangla phonetics
final bangla = BanglaPhonetics.instance;
final (:matches, :error) = await bangla.generate('মাসুদ', minScore: 90);
// মাসুদ 100%, মাসূদ 97%, মাশুদ 95%, মাষুদ 95%, মাশূদ 92.15%, মাষূদ 92.15%

// English phonetics
final english = EnglishPhonetics.instance;
final result = await english.generate('Philip', minScore: 90);
// Philip 100%, Filip 95%, Phillip 95%, Philipp 95%
```

| Platform | Runs on |
| --- | --- |
| Android, iOS, macOS, Windows, Linux | a background isolate |
| Web (JS and wasm builds) | a web worker, bundled in the package |
| Web page that blocks workers | the main thread, in 4 ms slices |

## Install

```bash
dart pub add flutter_phonetics
```

or in a Flutter app:

```bash
flutter pub add flutter_phonetics
```

## Usage

Calls never throw. Each one returns a record with the result and an `error`
that is `null` when everything went fine.

```dart
final (:matches, :error) = await phonetics.generate('মাসুদ');
if (error != null) {
  print(error.message);
  return;
}

for (final match in matches) {
  print('${match.word} ${match.score}% ${match.changes}');
}

final words = (await phonetics.generateWords('মাসুদ', minScore: 80)).words;
final score = (await phonetics.similarity('মাসুদ', 'মাছুদ')).score;
final isMatch =
    (await phonetics.matches('মাসুদ', 'মাছুদ', minScore: 80)).isMatch;
final ranked =
    await phonetics.rank('মাসুদ', customerNames, minScore: 80, limit: 10);
```

English works the same way, with the same calls, results and errors:

```dart
final english = EnglishPhonetics.instance;

final (:matches, :error) = await english.generate('Philip', minScore: 90);
// Philip 100%, Filip 95%, Phillip 95%, Philipp 95%,
// Fillip 90.25%, Phillipp 90.25%, Filipp 90.25%

final score = (await english.similarity('Catherine', 'Katherine')).score;
// 85.0

final isMatch = (await english.matches('Smith', 'Smyth', minScore: 80)).isMatch;
// true

final ranked = await english.rank(
  'Catherine',
  ['Katherine', 'Kathy', 'Michael'],
  minScore: 80,
);
// Katherine 85%
```

English ignores case and accents, and gives the result in the case you typed:
`generate('Philip')` returns `Filip`, and `generate('PHILIP')` returns `FILIP`.

`generate` options:

| Option | Default | |
| --- | --- | --- |
| `minScore` | 70 | only variants at or above this percentage |
| `maxResults` | 50 | stop after this many, or null for no limit (see below) |
| `includeOriginal` | true | include the input itself |
| `maxChanges` | none | at most this many letters swapped |

So `generate('Asad')` returns up to 50 variants that match at 70% or more. Pass
`minScore` and `maxResults` to change that, for example
`generate('Asad', minScore: 50, maxResults: 200)`.

**Recommended: `minScore` 70 and `maxResults` 50.** These give good performance
on every device: a call finishes in about a millisecond and uses no
measurable extra memory, and the variants you get are the ones that really sound
alike. Lowering `minScore` is what costs the most, because the number of
variants grows quickly (for an 11-letter name: 92 at 70, 741 at 50, 8,100 at 0).
See "Memory and limits" before going below these values.

Defaults of the other calls:

| Call | `minScore` | `maxResults` / `limit` |
| --- | --- | --- |
| `generate`, `generateWords` | 70 | `maxResults` 50 |
| `rank` | 0 | `limit` none |
| `matches` | 80 | not used |
| `similarity` | not used | not used |

`phonetics.workerName` tells you where the work ran: `isolate`, `web worker` or
`main thread (time-sliced)`.

