import '../../../tool/src/io/process_runner.dart';

/// A [ProcessRunner] that records what it ran, space-joined, and answers from closures.
class FakeProcessRunner implements ProcessRunner {
  new({this._onCapture, this._onRun});

  /// Every command run, in order.
  final List<String> calls = [];

  /// The same commands with the directory each ran in. Recorded because a command aimed at the
  /// wrong checkout looks identical in [calls].
  final List<({String command, String? workingDirectory})> invocations = [];

  final CommandResult Function(String command)? _onCapture;
  final CommandResult Function(String command)? _onRun;

  /// Whether any recorded command starts with [prefix].
  bool ran(String prefix) => calls.any((call) => call.startsWith(prefix));

  /// How many recorded commands start with [prefix].
  int timesRan(String prefix) => calls.where((call) => call.startsWith(prefix)).length;

  /// Where the first command starting with [prefix] ran, or null if it ran nowhere in particular.
  String? dirOf(String prefix) => invocations
      .where((invocation) => invocation.command.startsWith(prefix))
      .map((invocation) => invocation.workingDirectory)
      .firstOrNull;

  @override
  CommandResult capture(String executable, List<String> arguments, {String? workingDirectory}) {
    final command = _record(executable, arguments, workingDirectory);

    return _onCapture?.call(command) ?? const CommandResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final command = _record(executable, arguments, workingDirectory);

    return _onRun?.call(command) ?? const CommandResult(exitCode: 0, stdout: '', stderr: '');
  }

  String _record(String executable, List<String> arguments, String? workingDirectory) {
    final command = [executable, ...arguments].join(' ');
    calls.add(command);
    invocations.add((command: command, workingDirectory: workingDirectory));

    return command;
  }
}
