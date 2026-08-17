import '../../../tool/src/io/process_runner.dart';

/// A [ProcessRunner] that records what it ran, space-joined, and answers from closures.
class FakeProcessRunner implements ProcessRunner {
  new({this._onCapture, this._onStream});

  /// Every command run, in order.
  final List<String> calls = [];

  final CommandResult Function(String command)? _onCapture;
  final int Function(String command)? _onStream;

  /// Whether any recorded command starts with [prefix].
  bool ran(String prefix) => calls.any((call) => call.startsWith(prefix));

  /// How many recorded commands start with [prefix].
  int timesRan(String prefix) => calls.where((call) => call.startsWith(prefix)).length;

  @override
  CommandResult capture(String executable, List<String> arguments, {String? workingDirectory}) {
    final command = [executable, ...arguments].join(' ');
    calls.add(command);

    return _onCapture?.call(command) ?? const CommandResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<int> stream(String executable, List<String> arguments, {String? workingDirectory}) async {
    final command = [executable, ...arguments].join(' ');
    calls.add(command);

    return _onStream?.call(command) ?? 0;
  }
}
