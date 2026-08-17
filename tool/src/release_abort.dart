/// Exit code for a usage error, as opposed to a failed gate.
const usageErrorCode = 2;

/// Exit code convention for an interrupted process, which Dart does not apply on its own.
const interruptedCode = 130;

/// A release that stopped on purpose, carrying what to print and what to exit with.
///
/// Thrown rather than exited, because `exit()` skips `finally` and would skip the rollback with it.
/// The bash predecessor trapped `EXIT` rather than `ERR` for the mirror-image reason.
class ReleaseAbort implements Exception {
  new(String message, {this.code = 1}) : messages = List.unmodifiable([message]);

  /// An abort reporting every gate that failed, not just the first.
  new all(Iterable<String> messages, {this.code = 1}) : messages = List.unmodifiable(messages);

  /// Lines to print, in order, each already a complete sentence. Duplicates are meaningful: one
  /// finding's advice repeats per finding.
  final List<String> messages;

  /// What the process should exit with. `2` is a usage error, matching the predecessor.
  final int code;

  @override
  String toString() => messages.join('\n');
}
