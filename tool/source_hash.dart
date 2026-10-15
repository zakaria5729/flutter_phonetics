/// Author: Zakaria Hossain
/// Description: Utility computing deterministic hashes of worker source files.
library;

import 'dart:convert';
import 'dart:io';

const workerSourcePaths = [
  'lib/src/core',
  'lib/src/protocol',
  'tool/web_worker.dart',
];

String hashWorkerSources(String packageRoot) {
  final files = <File>[];
  for (final path in workerSourcePaths) {
    final fullPath = '$packageRoot/$path';
    if (FileSystemEntity.isDirectorySync(fullPath)) {
      files.addAll(Directory(fullPath)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')));
    } else {
      files.add(File(fullPath));
    }
  }

  String relativePath(File file) =>
      file.path.substring(packageRoot.length + 1).replaceAll(r'\', '/');
  files.sort((a, b) => relativePath(a).compareTo(relativePath(b)));

  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  void addBytes(List<int> bytes) {
    for (final byte in bytes) {
      hash ^= byte;
      hash *= prime;
    }
  }

  for (final file in files) {
    addBytes(utf8.encode(relativePath(file)));
    addBytes(utf8.encode(file.readAsStringSync().replaceAll('\r\n', '\n')));
  }
  return BigInt.from(hash).toUnsigned(64).toRadixString(16).padLeft(16, '0');
}
