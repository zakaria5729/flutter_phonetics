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

## Errors

`error` is a `PhoneticException`, a sealed class, so a `switch` can cover every
case. When there is an error the result is empty (`[]`, `0` or `false`).

| Error | When |
| --- | --- |
| `PhoneticCancelledException` | the call was cancelled, or the instance was disposed while it ran |
| `PhoneticArgumentException` | an argument is out of range, or the constructor settings are invalid |
| `PhoneticDisposedException` | the call was made after `dispose()` |
| `PhoneticWorkerException` | the worker failed or could not be started |

```dart
final text = switch (error) {
  null => 'ok',
  PhoneticCancelledException() => 'cancelled',
  PhoneticException(:final message) => message,
};
```

Constructors cannot return a record, so they never throw and keep the problem
in an `error` property instead. Every call on an object that has an error
returns that error, so it cannot go unnoticed:

```dart
final phonetics = BanglaPhonetics(gapSimilarity: 2);
final (:matches, :error) = await phonetics.generate('মাসুদ');
// error is a PhoneticArgumentException: gapSimilarity must be between 0 and 1
```

## Which instance to use

There are two ways to get a `BanglaPhonetics`, and they suit different jobs.

| | `BanglaPhonetics.instance` | `BanglaPhonetics()` |
| --- | --- | --- |
| What it is | one shared instance for the whole app, created on first use | a new instance with its own worker |
| Use it for | quick calls such as a search box | heavy or independent work, custom rules, a different mode |
| Execution mode | `cancelPrevious`, change it with `setExecutionMode` | `cancelPrevious`, or pass `executionMode:` |
| When you are done | nothing, leave it | call `dispose()` |

Every instance has one worker, and the execution mode applies to the calls of
that instance. Two features that must not disturb each other should not share
an instance.

```dart
final (:matches, :error) = await BanglaPhonetics.instance.generate('মাসুদ');

final importer = BanglaPhonetics();
final ranked = await importer.rank('মাসুদ', hugeCustomerList);
await importer.dispose();
```

## Execution mode

The execution mode decides what happens when a new call arrives while an
earlier call on the same instance is still running.

| Mode | What a new call does |
| --- | --- |
| `cancelPrevious` (default) | cancels everything still pending, then starts right away |
| `queue` | waits until the earlier calls have finished |

Call A takes 5 s and call B is made 1 s later:

| Mode | A | B |
| --- | --- | --- |
| `cancelPrevious` | cancelled at 1 s, returns a `PhoneticCancelledException` | returns at 6 s |
| `queue` | returns at 5 s | returns at 10 s |

Use `cancelPrevious` when only the latest call matters, like a search box. Use
`queue` when every call must finish.

```dart
final searchPhonetics = BanglaPhonetics();

final reportPhonetics =
    BanglaPhonetics(executionMode: PhoneticExecutionMode.queue);

BanglaPhonetics.instance.setExecutionMode(PhoneticExecutionMode.queue);
```

`setExecutionMode` works on any instance and affects the calls made after it.

Things to know:

- The mode applies to every call on the instance (`generate`, `rank`,
  `similarity` and the rest). A quick `similarity` call cancels a running
  `rank` on the same instance, so give heavy work its own `BanglaPhonetics()`.
- Calls that you await one after another never cancel each other.
- Starting several calls at once on one instance, for example with
  `Future.wait`, cancels all but the last in `cancelPrevious` mode. Use `queue`,
  or one instance per call.
- A call with invalid arguments, or with a token that is already cancelled,
  does not cancel anything.
- Tokens, `cancelAll()` and `dispose()` work in both modes.

The example app shows each of these: a search box on `BanglaPhonetics.instance`,
a heavy job on its own `BanglaPhonetics()`, and three calls at once in either
mode.

## Synchronous engine

`PhoneticEngine` is the same engine without the worker, for code that is
already on a background thread. It returns the same records, just not in a
`Future`, and it never throws either.

```dart
final engine = PhoneticEngine(language: englishLanguage);
final (:matches, :error) = engine.generate('Philip', minScore: 80);
final score = engine.similarity('Philip', 'Filip').score;
```

