/// Author: Zakaria Hossain
/// Description: Platform-conditional worker factory interface.
library;

import 'dart:async';

import '../cancel.dart';
import '../errors.dart';

export 'worker_unsupported.dart'
    if (dart.library.io) 'worker_io.dart';
