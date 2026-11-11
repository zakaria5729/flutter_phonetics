@TestOn('browser')
library;

import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/protocol/protocol.dart';
import 'package:flutter_phonetics/src/worker/worker_web.dart';
import 'package:test/test.dart';

import '../support/cross_language_support.dart';

void main() {
  const brokenScript = 'throw new Error("blocked");';

  test('a worker that fails to load falls back for cross-language requests',
      () async {
    final worker = WebWorker(
        encodeCrossLanguageConfig(PhoneticEngine(language: banglaLanguage)),
        scriptSource: brokenScript);
    addTearDown(worker.dispose);

    final payload = await worker.request(crossGenerateRequest('Masud',
        wantsBangla: true,
        wantsEnglish: true,
        banglaOptions: const PhoneticSearchOptions(minScore: 90),
        englishOptions: const PhoneticSearchOptions(minScore: 90)));
    final result = decodeCrossLanguageResult(payload);
    final direct = crossLanguageEngine.generate('Masud', minScore: 90);
    expect(result.bangla.matches, direct.bangla.matches);
    expect(result.english.matches, direct.english.matches);
    expect(worker.name, 'main thread (time-sliced)');
  });
}
