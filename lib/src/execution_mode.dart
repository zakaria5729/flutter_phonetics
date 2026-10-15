/// Author: Zakaria Hossain
/// Description: Execution mode configuration for concurrent phonetic requests.
library;

/// What to do when a request arrives while another one is running.
enum PhoneticExecutionMode {
  /// Run requests one after another.
  queue,

  /// Cancel the running request and start the new one. This is the default.
  cancelPrevious,
}
