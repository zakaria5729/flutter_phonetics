/// Author: Zakaria Hossain
/// Description: Tests validating graceful fallback to time-sliced execution on web.
@TestOn('browser')
library;

import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/protocol/protocol.dart';
import 'package:flutter_phonetics/src/worker/worker_web.dart';
import 'package:test/test.dart';

import 'support/workload.dart';

void main() {
  final brokenScript = 'throw new Error("blocked");';

  test('a worker that fails to load falls back to time-sliced work', () async {
    final engine = PhoneticEngine(language: banglaLanguage);
    final worker =
        WebWorker(encodeEngineConfig(engine), scriptSource: brokenScript);
    addTearDown(worker.dispose);

    final flatMatches =
        await worker.request(generateRequest('আসাদ', 80, 100, true, null));
    expect(decodeMatches(flatMatches),
        engine.generate('আসাদ', minScore: 80).matches);
    expect(worker.name, 'main thread (time-sliced)');

    final similarity = await worker.request(similarityRequest('আসাদ', 'আছাদ'));
    expect(decodeSimilarity(similarity), 85);
  });

  test('cancelling still works after falling back', () async {
    final engine = PhoneticEngine(language: banglaLanguage);
    final workload = buildWorkload(engine);
    final worker =
        WebWorker(encodeEngineConfig(engine), scriptSource: brokenScript);
    addTearDown(worker.dispose);

    final token = PhoneticCancelToken();
    final call = worker.request(
        rankRequest(heavyQuery, workload.names, 0, null),
        cancelToken: token);
    final failed =
        expectLater(call, throwsA(isA<PhoneticCancelledException>()));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(worker.name, 'main thread (time-sliced)');
    token.cancel();
    await failed;

    final stopwatch = Stopwatch()..start();
    final similarity = await worker.request(similarityRequest('আসাদ', 'আছাদ'));
    expect(decodeSimilarity(similarity), 85);
    expect(stopwatch.elapsedMilliseconds, lessThan(workload.directRunMs ~/ 3));
  });
}
