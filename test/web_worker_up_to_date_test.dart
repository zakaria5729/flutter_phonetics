/// Author: Zakaria Hossain
/// Description: Test verifying the embedded web worker script is synchronized with sources.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_phonetics/src/worker/web_worker_script.g.dart';
import 'package:test/test.dart';

import '../tool/source_hash.dart';

void main() {
  test('embedded web worker script matches the current sources', () {
    expect(hashWorkerSources(Directory.current.path), workerSourceHash,
        reason: 'Run: dart run tool/build_web_worker.dart');
  });
}
