/// Author: Zakaria Hossain
/// Description: Test utilities and workloads for benchmark and stress tests.
library;

import 'package:flutter_phonetics/flutter_phonetics.dart';

const heavyQuery = 'আসাদুজ্জামান শরীফ রহিম';

const _nameParts = [
  'আসাদ',
  'শরীফ',
  'রহিম',
  'করিম',
  'নাজনীন',
  'জসীম',
  'সৈয়দ',
  'কৃষক',
];

class Workload {
  Workload(this.names, this.directRunMs);

  final List<String> names;
  final int directRunMs;
}

List<String> buildNames(int count) => [
      for (var i = 0; i < count; i++)
        '${_nameParts[i % 8]} ${_nameParts[(i * 3) % 8]} '
            '${_nameParts[(i * 5) % 8]} $i',
    ];

Workload buildWorkload(PhoneticEngine engine, {int targetMs = 500}) {
  var count = 20000;
  while (true) {
    final names = buildNames(count);
    final stopwatch = Stopwatch()..start();
    engine.rank(heavyQuery, names);
    final elapsedMs = stopwatch.elapsedMilliseconds;
    if (elapsedMs >= targetMs || count >= 2000000) {
      return Workload(names, elapsedMs);
    }
    count *= 2;
  }
}
