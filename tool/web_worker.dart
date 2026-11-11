/// Author: Zakaria Hossain
/// Description: Web worker entry point compiled to JavaScript for web platforms.
library;

import 'dart:js_interop';

import 'package:flutter_phonetics/src/protocol/protocol.dart';
import 'package:web/web.dart' as web;

void main() {
  final scope = globalContext as web.DedicatedWorkerGlobalScope;
  RequestProcessor? processor;

  RequestProcessor createProcessor(Map<Object?, Object?> config) =>
      RequestProcessor.fromConfig(
        config,
        (response) => scope.postMessage(response.jsify()),
        sliceDuration: const Duration(milliseconds: 10),
      );

  scope.onmessage = (web.MessageEvent event) {
    final message = event.data.dartify();
    if (message is! Map) return;
    if (message['op'] == 'init') {
      final config = message['config'];
      processor = createProcessor(config is Map ? config : const {});
      scope.postMessage({'id': -1, 'ok': true}.jsify());
      return;
    }
    (processor ??= createProcessor(const {})).onMessage(message);
  }.toJS;
}
