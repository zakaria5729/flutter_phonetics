/// Author: Zakaria Hossain
/// Description: Demo application showcasing phonetic variant generation and stress testing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_phonetics/flutter_phonetics.dart';

void main() => runApp(const PhoneticsDemoApp());

enum PhoneticsLanguageChoice {
  bangla(
    label: 'Bangla (বাংলা)',
    className: 'BanglaPhonetics',
    defaultSearch: 'মাসুদ',
    inputLabel: 'বাংলা শব্দ (Bangla word)',
    heavyQuery: 'মাছুদ শরিফ রহীম',
    sampleWords: ['মাসুদ', 'শরীফ', 'রহিম', 'নাজনীন', 'সৈয়দ', 'করিম'],
    nameParts: ['মাসুদ', 'শরীফ', 'রহিম', 'করিম', 'নাজনীন', 'জসীম', 'সৈয়দ'],
    defaultPair: ('মাসুদ', 'মাছুদ'),
    samplePairs: [('মাসুদ', 'মাছুদ'), ('শরীফ', 'শরিফ'), ('রহিম', 'রহীম')],
  ),
  english(
    label: 'English',
    className: 'EnglishPhonetics',
    defaultSearch: 'Philip',
    inputLabel: 'English word',
    heavyQuery: 'Stefen Smyth Filip',
    sampleWords: ['Philip', 'Stephen', 'Jackson', 'Smith', 'Sean', 'Catherine'],
    nameParts: [
      'Stephen',
      'Smith',
      'Katherine',
      'Philip',
      'Jackson',
      'Sean',
      'Bryan',
    ],
    defaultPair: ('Stephen', 'Stefen'),
    samplePairs: [
      ('Stephen', 'Stefen'),
      ('Philip', 'Filip'),
      ('Smith', 'Smyth'),
      ('Jackson', 'Jaxon'),
      ('Catherine', 'Katherine'),
    ],
  );

  const PhoneticsLanguageChoice({
    required this.label,
    required this.className,
    required this.defaultSearch,
    required this.inputLabel,
    required this.heavyQuery,
    required this.sampleWords,
    required this.nameParts,
    required this.defaultPair,
    required this.samplePairs,
  });

  final String label;
  final String className;
  final String defaultSearch;
  final String inputLabel;
  final String heavyQuery;
  final List<String> sampleWords;
  final List<String> nameParts;
  final (String, String) defaultPair;
  final List<(String, String)> samplePairs;

  Phonetics get instance => switch (this) {
    PhoneticsLanguageChoice.bangla => BanglaPhonetics.instance,
    PhoneticsLanguageChoice.english => EnglishPhonetics.instance,
  };

  Phonetics createInstance({PhoneticExecutionMode? executionMode}) =>
      switch (this) {
        PhoneticsLanguageChoice.bangla => BanglaPhonetics(
          executionMode: executionMode ?? PhoneticExecutionMode.cancelPrevious,
        ),
        PhoneticsLanguageChoice.english => EnglishPhonetics(
          executionMode: executionMode ?? PhoneticExecutionMode.cancelPrevious,
        ),
      };

  List<String> buildCustomerNames(int count) => [
    for (var i = 0; i < count; i++)
      '${nameParts[i % nameParts.length]} '
          '${nameParts[(i * 3) % nameParts.length]} '
          '${nameParts[(i * 5) % nameParts.length]} $i',
  ];
}

class PhoneticsDemoApp extends StatelessWidget {
  const PhoneticsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_phonetics',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E293B),
        useMaterial3: true,
      ),
      home: const PhoneticsPage(),
    );
  }
}

class PhoneticsPage extends StatefulWidget {
  const PhoneticsPage({super.key});

  @override
  State<PhoneticsPage> createState() => _PhoneticsPageState();
}

class _PhoneticsPageState extends State<PhoneticsPage> {
  PhoneticsLanguageChoice _language = PhoneticsLanguageChoice.bangla;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('flutter_phonetics (${_language.label})'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                avatar: const Icon(Icons.bolt, size: 16),
                label: Text(
                  _language.instance.workerName,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.language, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Language:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SegmentedButton<PhoneticsLanguageChoice>(
                        segments: const [
                          ButtonSegment(
                            value: PhoneticsLanguageChoice.bangla,
                            label: Text('বাংলা (Bangla)'),
                            icon: Icon(Icons.translate),
                          ),
                          ButtonSegment(
                            value: PhoneticsLanguageChoice.english,
                            label: Text('English'),
                            icon: Icon(Icons.abc),
                          ),
                        ],
                        selected: {_language},
                        onSelectionChanged: (selection) {
                          setState(() => _language = selection.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SearchSection(
              key: ValueKey('search_${_language.name}'),
              language: _language,
            ),
            const SizedBox(height: 16),
            PairwiseSection(
              key: ValueKey('pair_${_language.name}'),
              language: _language,
            ),
            const SizedBox(height: 16),
            HeavyJobSection(
              key: ValueKey('heavy_${_language.name}'),
              language: _language,
            ),
            const SizedBox(height: 16),
            ThreeCallsSection(
              key: ValueKey('three_${_language.name}'),
              language: _language,
            ),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class SearchSection extends StatefulWidget {
  const SearchSection({super.key, required this.language});

  final PhoneticsLanguageChoice language;

  @override
  State<SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<SearchSection> {
  late final Phonetics _phonetics = widget.language.instance;
  late final TextEditingController _input = TextEditingController(
    text: widget.language.defaultSearch,
  );

  double _minScore = 70;
  bool _hasLimit = true;
  int _maxResults = 50;
  bool _usesQueue = false;
  List<PhoneticMatch> _matches = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _phonetics.cancelAll();
    _phonetics.setExecutionMode(PhoneticExecutionMode.cancelPrevious);
    _input.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final (:matches, :error) = await _phonetics.generate(
      _input.text,
      minScore: _minScore,
      maxResults: _hasLimit ? _maxResults : null,
    );
    if (!mounted || error is PhoneticCancelledException) return;
    setState(() {
      _matches = matches;
      _errorMessage = error?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '1. Search box: ${widget.language.className}.instance',
      description:
          'One shared instance for quick calls. By default it uses '
          'cancelPrevious, so each new keystroke cancels the search still '
          'running for the one before it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _input,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              labelText: widget.language.inputLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _search(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Quick test:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final word in widget.language.sampleWords)
                ActionChip(
                  label: Text(word),
                  onPressed: () {
                    _input.text = word;
                    _search();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Percentage slider
          Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  'Minimum match: ${_minScore.round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Slider(
                  value: _minScore,
                  max: 100,
                  divisions: 20,
                  label: '${_minScore.round()}%',
                  onChanged: (value) {
                    setState(() => _minScore = value);
                    _search();
                  },
                ),
              ),
            ],
          ),
          // Max returning limit (optional)
          Row(
            children: [
              SizedBox(
                width: 150,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _hasLimit,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) {
                        setState(() => _hasLimit = val ?? true);
                        _search();
                      },
                    ),
                    Flexible(
                      child: Text(
                        _hasLimit ? 'Limit: $_maxResults' : 'No limit',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _hasLimit
                              ? null
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _hasLimit
                    ? Slider(
                        value: _maxResults.toDouble().clamp(5, 200),
                        min: 5,
                        max: 200,
                        divisions: 39,
                        label: '$_maxResults',
                        onChanged: (value) {
                          setState(() => _maxResults = value.round());
                          _search();
                        },
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Unlimited (all matching phonetics)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
              if (_hasLimit)
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 20,
                      label: Text('20', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: 50,
                      label: Text('50', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: 100,
                      label: Text('100', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {_maxResults},
                  onSelectionChanged: (selected) {
                    setState(() => _maxResults = selected.first);
                    _search();
                  },
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Queue instead of cancelPrevious'),
            subtitle: Text(
              '${widget.language.className}.instance.setExecutionMode',
            ),
            value: _usesQueue,
            onChanged: (value) {
              setState(() => _usesQueue = value);
              _phonetics.setExecutionMode(
                value
                    ? PhoneticExecutionMode.queue
                    : PhoneticExecutionMode.cancelPrevious,
              );
            },
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_matches.length} variants'
                '${_hasLimit && _matches.length >= _maxResults ? ' (capped at $_maxResults)' : ''}',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                _hasLimit ? 'Limit: $_maxResults max' : 'Unlimited results',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _hasLimit
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          SizedBox(
            height: 260,
            child: ListView.builder(
              itemCount: _matches.length,
              itemBuilder: (context, index) {
                final match = _matches[index];
                return ListTile(
                  dense: true,
                  title: Text(match.word, style: const TextStyle(fontSize: 20)),
                  subtitle: match.changes.isEmpty
                      ? const Text('original')
                      : Text(match.changes.join('  ')),
                  trailing: Text(
                    '${match.score.toStringAsFixed(match.score % 1 == 0 ? 0 : 2)}%',
                    style: theme.textTheme.titleMedium,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PairwiseSection extends StatefulWidget {
  const PairwiseSection({super.key, required this.language});

  final PhoneticsLanguageChoice language;

  @override
  State<PairwiseSection> createState() => _PairwiseSectionState();
}

class _PairwiseSectionState extends State<PairwiseSection> {
  late final Phonetics _phonetics = widget.language.createInstance();
  late final TextEditingController _word1 = TextEditingController(
    text: widget.language.defaultPair.$1,
  );
  late final TextEditingController _word2 = TextEditingController(
    text: widget.language.defaultPair.$2,
  );

  double? _score;
  bool? _isMatch;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _compare();
  }

  @override
  void dispose() {
    _phonetics.dispose();
    _word1.dispose();
    _word2.dispose();
    super.dispose();
  }

  Future<void> _compare() async {
    final phonetics = _phonetics;
    final w1 = _word1.text.trim();
    final w2 = _word2.text.trim();
    if (w1.isEmpty || w2.isEmpty) {
      setState(() {
        _score = 0;
        _isMatch = false;
        _errorMessage = null;
      });
      return;
    }
    final (:score, :error) = await phonetics.similarity(w1, w2);
    final matchResult = await phonetics.matches(w1, w2, minScore: 80);
    if (!mounted) return;
    setState(() {
      _score = score;
      _isMatch = matchResult.isMatch;
      _errorMessage = error?.message ?? matchResult.error?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '2. Pairwise similarity: similarity() & matches()',
      description:
          'Compare two ${widget.language.label} words to see their phonetic '
          'similarity percentage and whether they meet the match threshold (≥ 80%).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _word1,
                  decoration: const InputDecoration(
                    labelText: 'Word 1',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _compare(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _word2,
                  decoration: const InputDecoration(
                    labelText: 'Word 2',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _compare(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Sample pairs:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final pair in widget.language.samplePairs)
                ActionChip(
                  label: Text('${pair.$1} ↔ ${pair.$2}'),
                  onPressed: () {
                    _word1.text = pair.$1;
                    _word2.text = pair.$2;
                    _compare();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            )
          else if (_score != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Similarity: ${_score!.toStringAsFixed(_score! % 1 == 0 ? 0 : 2)}%',
                    style: theme.textTheme.titleMedium,
                  ),
                  Chip(
                    avatar: Icon(
                      _isMatch == true ? Icons.check_circle : Icons.cancel,
                      color: _isMatch == true ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                    label: Text(
                      _isMatch == true ? 'Match (≥80%)' : 'No Match (<80%)',
                      style: TextStyle(
                        color: _isMatch == true
                            ? Colors.green[800]
                            : Colors.orange[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class HeavyJobSection extends StatefulWidget {
  const HeavyJobSection({super.key, required this.language});

  final PhoneticsLanguageChoice language;

  @override
  State<HeavyJobSection> createState() => _HeavyJobSectionState();
}

class _HeavyJobSectionState extends State<HeavyJobSection> {
  Phonetics? _phonetics;
  PhoneticCancelToken? _cancelToken;
  bool _isRunning = false;
  String _status = '';

  @override
  void dispose() {
    _cancelToken?.cancel();
    _phonetics?.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final phonetics = _phonetics = widget.language.createInstance();
    final cancelToken = _cancelToken = PhoneticCancelToken();
    setState(() {
      _isRunning = true;
      _status = 'Ranking 100,000 ${widget.language.label} names…';
    });

    final names = widget.language.buildCustomerNames(100000);
    final stopwatch = Stopwatch()..start();
    final (:matches, :error) = await phonetics.rank(
      widget.language.heavyQuery,
      names,
      limit: 3,
      cancelToken: cancelToken,
    );
    await phonetics.dispose();
    if (identical(_phonetics, phonetics)) _phonetics = null;
    if (!mounted) return;

    final status = switch (error) {
      null =>
        '${stopwatch.elapsedMilliseconds} ms. Best: '
            '${matches.map((match) => '${match.word} ${match.score.toStringAsFixed(match.score % 1 == 0 ? 0 : 2)}%').join(', ')}',
      PhoneticCancelledException() =>
        'Cancelled after ${stopwatch.elapsedMilliseconds} ms',
      PhoneticException(:final message) => message,
    };
    setState(() {
      _isRunning = false;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '3. Heavy job: its own ${widget.language.className}()',
      description:
          'A big job gets its own instance, created when it starts '
          'and disposed when it ends. Typing in the search box above does not '
          'cancel it, and the spinner keeps turning because the work runs on '
          'a background thread.',
      child: Row(
        children: [
          if (_isRunning)
            OutlinedButton(
              onPressed: () => _cancelToken?.cancel(),
              child: const Text('Cancel'),
            )
          else
            FilledButton.tonal(
              onPressed: _run,
              child: const Text('Stress test'),
            ),
          const SizedBox(width: 12),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_status)),
        ],
      ),
    );
  }
}

class ThreeCallsSection extends StatefulWidget {
  const ThreeCallsSection({super.key, required this.language});

  final PhoneticsLanguageChoice language;

  @override
  State<ThreeCallsSection> createState() => _ThreeCallsSectionState();
}

class _ThreeCallsSectionState extends State<ThreeCallsSection> {
  PhoneticExecutionMode _mode = PhoneticExecutionMode.cancelPrevious;
  bool _isRunning = false;
  List<String> _lines = const [];

  Future<void> _run() async {
    setState(() {
      _isRunning = true;
      _lines = const [];
    });

    final phonetics = widget.language.createInstance(executionMode: _mode);
    final names = widget.language.buildCustomerNames(30000);
    final stopwatch = Stopwatch()..start();
    final lines = List<String>.filled(3, '');

    await Future.wait([
      for (var index = 0; index < 3; index++)
        phonetics.rank(widget.language.heavyQuery, names, limit: 1).then((
          result,
        ) {
          final elapsed = stopwatch.elapsedMilliseconds;
          lines[index] = result.error is PhoneticCancelledException
              ? 'Call ${index + 1}: cancelled after $elapsed ms'
              : 'Call ${index + 1}: done in $elapsed ms';
        }),
    ]);
    await phonetics.dispose();
    if (!mounted) return;

    setState(() {
      _isRunning = false;
      _lines = lines;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '4. Three calls at once: cancelPrevious or queue',
      description:
          'The three calls are made together on a new '
          '${widget.language.className}(executionMode: ...). cancelPrevious: each new call '
          'cancels the one before, so only the last finishes. queue: each call '
          'waits for the one before it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<PhoneticExecutionMode>(
            segments: const [
              ButtonSegment(
                value: PhoneticExecutionMode.cancelPrevious,
                label: Text('cancelPrevious'),
              ),
              ButtonSegment(
                value: PhoneticExecutionMode.queue,
                label: Text('queue'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _isRunning
                ? null
                : (selection) => setState(() => _mode = selection.first),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _isRunning ? null : _run,
            child: const Text('Run 3 calls'),
          ),
          const SizedBox(height: 8),
          for (final line in _lines) Text(line),
        ],
      ),
    );
  }
}
