import 'package:flutter_phonetics/flutter_phonetics.dart';

const _nameParts = [
  'আসাদুজ্জামান',
  'শরীফ',
  'রহিম',
  'মোহাম্মদ',
  'আব্দুল্লাহ',
  'জাহাঙ্গীর',
  'নাজনীন',
  'ইব্রাহিম',
];

class CrossLanguageWorkload {
  CrossLanguageWorkload(this.input, this.directRunMs);

  final String input;
  final int directRunMs;
}

String buildLongBanglaName(int partCount) => [
      for (var i = 0; i < partCount; i++)
        _nameParts[(i * 3) % _nameParts.length],
    ].join(' ');

CrossLanguageWorkload buildCrossLanguageWorkload(
  CrossLanguageEngine engine, {
  int targetMs = 500,
}) {
  var partCount = 8;
  while (true) {
    final input = buildLongBanglaName(partCount);
    final stopwatch = Stopwatch()..start();
    engine.generate(input, minScore: 0, maxResults: null);
    final elapsedMs = stopwatch.elapsedMilliseconds;
    if (elapsedMs >= targetMs || partCount >= 4096) {
      return CrossLanguageWorkload(input, elapsedMs);
    }
    partCount *= 2;
  }
}
