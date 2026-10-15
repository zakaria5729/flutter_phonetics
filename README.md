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

## Memory and limits

Measured on a native build, on top of about 14 MB for the process:

| Call | Results | Extra memory |
| --- | --- | --- |
| a name with the defaults (`minScore` 70, `maxResults` 50) | up to 50 | none you can measure |
| an 11-letter name, `minScore` 0, no limit | 8,100 | 13 MB |
| a 30-letter name, `maxResults` 10,000 | 10,000 | 13 MB |
| a 30-letter name, `minScore` 0, no limit (the ceiling) | 100,000 | 110 MB |

The number of variants grows quickly as `minScore` falls: for an 11-letter name
it is 92 at 70, 741 at 50 and 8,100 at 0. Raising `minScore` is the strongest
way to save memory. The worker sends results to your isolate as a copy, so
budget about two to three times the figures above while a large result is in
flight.

Safe settings:

| Device | `minScore` | `maxResults` |
| --- | --- | --- |
| Low-end phones and mobile browsers | 60 or more | 500 or less |
| Recommended (the defaults) | 70 | 50 |
| Desktop or batch work | 40 or more | 10,000 or less |

A list in the UI never needs more than a few hundred rows.

`rank` holds your candidate list (copied once for the worker) and keeps only
`limit` matches, so use a `limit`. Time is the bigger cost: about 24 microseconds
per name, so 100,000 names take around 2.4 seconds on a worker thread and
500,000 take around 12. Split very large lists, or filter them first.

## Benchmark

**> 90% accuracy gain via test with dataset**

Dataset download links:

**Bangla (bn)**

- https://github.com/google/language-resources/tree/master/bn/data
- https://github.com/google-research-datasets/dakshina
- https://huggingface.co/datasets/ai4bharat/Aksharantar

**English (en)**

- https://github.com/cmusphinx/cmudict
- https://llds.phon.ox.ac.uk/llds/xmlui/handle/20.500.14106/0643
- https://github.com/mhagiwara/github-typo-corpus

## Languages

A language is a plain definition: its rules, and how its text is normalized
before comparing. The engine, the worker and the instances know nothing about
any particular language.

| Language | Definition | Class | Shared instance |
| --- | --- | --- | --- |
| Bangla | `banglaLanguage` | `BanglaPhonetics` | `BanglaPhonetics.instance` |
| English | `englishLanguage` | `EnglishPhonetics` | `EnglishPhonetics.instance` |

English ignores case and accents, treats `'` and `-` as marks, and keeps the
case of what you type: `Asad` gives `Assad`, `ASAD` gives `ASSAD`.

The rule weights for the built-in languages are starting points. Tune them
with your own data.

