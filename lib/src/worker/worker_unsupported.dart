/// Author: Zakaria Hossain
/// Description: Fallback stub for unsupported platforms.
library;

import 'time_sliced_worker.dart';
import 'worker.dart';

PhoneticWorker createPhoneticWorker(Map<String, Object?> engineConfig) =>
    TimeSlicedWorker(engineConfig);
