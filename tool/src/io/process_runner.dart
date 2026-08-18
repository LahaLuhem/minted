import 'dart:io';

/// Every external command the release flow runs, behind one seam.
///
/// Injected so the order of the git calls, and what gets undone when one fails, is unit-testable
/// rather than only observable by cutting a real release.
abstract interface class ProcessRunner {
  /// Runs [executable] and captures its output, for commands whose output is parsed.
  CommandResult capture(String executable, List<String> arguments, {String? workingDirectory});

  /// Runs [executable] asynchronously, capturing its output.
  ///
  /// Both, so a spinner can animate over it and keep the terminal to itself.
  Future<CommandResult> run(String executable, List<String> arguments, {String? workingDirectory});
}

class CommandResult {
  const new({required this.exitCode, required this.stdout, required this.stderr})
    : notFound = false;

  /// A command that could not be started, which is how a missing tool reads.
  const new notFound() : exitCode = -1, stdout = '', stderr = '', notFound = true;

  final int exitCode;
  final String stdout;
  final String stderr;

  /// Whether the executable itself was missing, as opposed to running and failing.
  final bool notFound;

  bool get ok => exitCode == 0;
}

class RealProcessRunner implements ProcessRunner {
  const new();

  @override
  CommandResult capture(String executable, List<String> arguments, {String? workingDirectory}) {
    try {
      final result = Process.runSync(executable, arguments, workingDirectory: workingDirectory);

      return CommandResult(
        exitCode: result.exitCode,
        stdout: (result.stdout as String).trim(),
        stderr: (result.stderr as String).trim(),
      );
    } on ProcessException {
      return const CommandResult.notFound();
    }
  }

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      final result = await Process.run(executable, arguments, workingDirectory: workingDirectory);

      return CommandResult(
        exitCode: result.exitCode,
        stdout: (result.stdout as String).trim(),
        stderr: (result.stderr as String).trim(),
      );
    } on ProcessException {
      return const CommandResult.notFound();
    }
  }
}
