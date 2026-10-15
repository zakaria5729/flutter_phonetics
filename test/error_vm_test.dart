/// Author: Zakaria Hossain
/// Description: Tests simulating isolate crash and VM error handling.
@TestOn('vm')
library;

import 'dart:isolate';

import 'package:flutter_phonetics/flutter_phonetics.dart';
import 'package:flutter_phonetics/src/protocol/protocol.dart';
import 'package:flutter_phonetics/src/worker/worker_io.dart';
import 'package:test/test.dart';

class UnsendableRules implements PhoneticRuleSet {
  @override
  PhoneticArgumentException? get error => null;

  @override
  String get languageCode => 'bn';

  @override
  List<Object> toJson() => [RawReceivePort()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void crashOnStart(List<Object?> arguments) {
  throw StateError('crash on start');
}

void crashOnFirstRequest(List<Object?> arguments) {
  final mainPort = arguments[0]! as SendPort;
  final port = RawReceivePort((Object? message) {
    throw StateError('crash on request');
  });
  mainPort.send(port.sendPort);
}

void exitOnStart(List<Object?> arguments) {}

void main() {
  final config = encodeEngineConfig(PhoneticEngine(language: banglaLanguage));
  final isWorkerException = throwsA(isA<PhoneticWorkerException>());

  test('an isolate that crashes while starting fails its requests', () async {
    final worker = IsolateWorker(config, entryPoint: crashOnStart);
    addTearDown(worker.dispose);
    await expectLater(
        worker.request(similarityRequest('আসাদ', 'আছাদ')), isWorkerException);
    await expectLater(
        worker.request(similarityRequest('আসাদ', 'আছাদ')), isWorkerException);
  });

  test('an isolate that exits right away fails its requests', () async {
    final worker = IsolateWorker(config, entryPoint: exitOnStart);
    addTearDown(worker.dispose);
    await expectLater(
        worker.request(similarityRequest('আসাদ', 'আছাদ')), isWorkerException);
  });

  test('an isolate that crashes mid-request fails everything in flight',
      () async {
    final worker = IsolateWorker(config, entryPoint: crashOnFirstRequest);
    addTearDown(worker.dispose);
    final first = worker.request(similarityRequest('আসাদ', 'আছাদ'));
    final second = worker.request(similarityRequest('আসাদ', 'আশাদ'));
    await expectLater(first, isWorkerException);
    await expectLater(second, isWorkerException);
  });

  test('a config the worker cannot use fails requests, not the isolate',
      () async {
    final worker = IsolateWorker({
      'rules': 'not a list of rules',
      'gap': 0.5,
      'markGap': 0.85,
      'unrelated': 0.4,
    });
    addTearDown(worker.dispose);
    await expectLater(
        worker.request(similarityRequest('আসাদ', 'আছাদ')), isWorkerException);
    await expectLater(
        worker.request(similarityRequest('আসাদ', 'আছাদ')), isWorkerException);
  });

  test('settings that cannot reach the isolate come back as a worker error',
      () async {
    final broken = BanglaPhonetics(rules: UnsendableRules());
    addTearDown(broken.dispose);

    final (:matches, :error) = await broken.generate('আসাদ');
    expect(error, isA<PhoneticWorkerException>());
    expect(matches, isEmpty);
    expect((await broken.similarity('আসাদ', 'আছাদ')).error,
        isA<PhoneticWorkerException>());
  });
}
