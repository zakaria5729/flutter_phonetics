import 'package:flutter/material.dart';
import 'package:flutter_phonetics/flutter_phonetics.dart';

enum CrossLanguageInput {
  bangla(
    label: 'Bangla name',
    inputLabel: 'বা\u0982লা নাম (Bangla name)',
    defaultName: 'রহিম',
    sampleNames: [
      'রহিম',
      'মাসুদ',
      'ফারজানা',
      'মোহাম্মদ আব্দুল',
      'আয\u09BC\u09C7শা',
    ],
  ),
  english(
    label: 'English name',
    inputLabel: 'English name',
    defaultName: 'Rahim',
    sampleNames: ['Rahim', 'Masud', 'Farzana', 'Abdul Karim', 'Ayesha'],
  );

  const CrossLanguageInput({
    required this.label,
    required this.inputLabel,
    required this.defaultName,
    required this.sampleNames,
  });

  final String label;
  final String inputLabel;
  final String defaultName;
  final List<String> sampleNames;
}

class CrossLanguageSection extends StatefulWidget {
  const CrossLanguageSection({super.key});

  @override
  State<CrossLanguageSection> createState() => _CrossLanguageSectionState();
}

class _CrossLanguageSectionState extends State<CrossLanguageSection> {
  final CrossLanguagePhonetics _crossLanguage = CrossLanguagePhonetics();
  late final TextEditingController _input = TextEditingController(
    text: _inputLanguage.defaultName,
  );

  CrossLanguageInput _inputLanguage = CrossLanguageInput.bangla;
  double _minScore = 80;
  CrossLanguageResult? _result;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _crossLanguage.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final result = await _crossLanguage.generate(
      _input.text,
      minScore: _minScore,
      maxResults: 50,
    );
    if (!mounted || result.error is PhoneticCancelledException) return;
    setState(() => _result = result);
  }

  void _chooseInputLanguage(CrossLanguageInput choice) {
    setState(() => _inputLanguage = choice);
    _input.text = choice.defaultName;
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final banglaIsInput = _inputLanguage == CrossLanguageInput.bangla;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '5. Cross-language names: its own CrossLanguagePhonetics()',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Type a Bangla or an English name. The list in the other '
              'script is built from how the name sounds, not by '
              'transliterating it. The two lists are scored separately, so '
              'compare scores only inside one list.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final choice in CrossLanguageInput.values)
                  ChoiceChip(
                    label: Text(choice.label),
                    selected: choice == _inputLanguage,
                    onSelected: (_) => _chooseInputLanguage(choice),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                labelText: _inputLanguage.inputLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _generate(),
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
                for (final name in _inputLanguage.sampleNames)
                  ActionChip(
                    label: Text(name),
                    onPressed: () {
                      _input.text = name;
                      _generate();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
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
                      _generate();
                    },
                  ),
                ),
              ],
            ),
            const Divider(),
            if (result?.error case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error.message,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SpellingColumn(
                    title: 'Bangla spellings',
                    result: result?.bangla,
                    firstMatchLabel: banglaIsInput
                        ? 'original'
                        : 'best reading',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SpellingColumn(
                    title: 'English spellings',
                    result: result?.english,
                    firstMatchLabel: banglaIsInput
                        ? 'best reading'
                        : 'original',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpellingColumn extends StatelessWidget {
  const _SpellingColumn({
    required this.title,
    required this.result,
    required this.firstMatchLabel,
  });

  final String title;
  final PhoneticMatchesResult? result;
  final String firstMatchLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = result?.matches ?? const <PhoneticMatch>[];
    final error = result?.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title (${matches.length})', style: theme.textTheme.titleSmall),
        if (error != null)
          Text(
            error.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        SizedBox(
          height: 260,
          child: ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              final isFirst = match.changes.isEmpty;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(match.word, style: const TextStyle(fontSize: 20)),
                subtitle: isFirst ? Text(firstMatchLabel) : null,
                trailing: Text(
                  '${match.score.toStringAsFixed(match.score % 1 == 0 ? 0 : 2)}%',
                  style: theme.textTheme.titleSmall,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
