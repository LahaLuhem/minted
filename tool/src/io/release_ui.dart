import 'dart:io';

import '../versioning/bump_type.dart';

/// Everything the release flow needs from a person or says to one.
///
/// One seam, so a richer implementation can replace the prompts without the flow above changing.
abstract interface class ReleaseUi {
  /// A progress line.
  void log(String message);

  /// A section boundary, for the gates that take a while.
  void step(String message);

  /// A failure line, on stderr.
  void error(String message);

  /// Printed unprefixed: the plan, the usage text.
  void block(String text);

  /// Runs [work] under a progress indication labelled [label], so a slow gate can show one.
  Future<T> task<T>(String label, Future<T> Function() work);

  /// Whether there is someone there to answer a prompt.
  bool get isInteractive;

  /// Null from either chooser means the choice was not made.
  String? choosePackage(List<String> names);

  BumpType? chooseBump();

  bool confirmRelease();
}

class StdioReleaseUi implements ReleaseUi {
  const new();

  @override
  void log(String message) => stdout.writeln('[release] $message');

  @override
  void step(String message) => stdout.writeln('\n[release] == $message ==');

  @override
  void error(String message) => stderr.writeln('[release] ERROR: $message');

  @override
  void block(String text) => stdout.writeln(text);

  @override
  Future<T> task<T>(String label, Future<T> Function() work) {
    step(label);

    return work();
  }

  @override
  bool get isInteractive => stdin.hasTerminal;

  @override
  String? choosePackage(List<String> names) {
    if (!isInteractive) return null;

    stderr.writeln('Packages with unreleased notes:');
    for (final (index, name) in names.indexed) {
      stderr.writeln('  ${index + 1}) $name');
    }

    while (true) {
      stderr.write('Release which? [1-${names.length}]: ');
      final choice = int.tryParse(stdin.readLineSync()?.trim() ?? '');
      if (choice != null && choice >= 1 && choice <= names.length) {
        return names[choice - 1];
      }

      stderr.writeln('Please enter a number between 1 and ${names.length}.');
    }
  }

  @override
  BumpType? chooseBump() {
    if (!isInteractive) return null;

    while (true) {
      stderr.write('Bump type [${BumpType.names}] (default: patch): ');
      final reply = stdin.readLineSync()?.trim() ?? '';
      if (reply.isEmpty) return .patch;

      final bump = BumpType.tryParse(reply);
      if (bump != null) return bump;

      stderr.writeln('Please enter one of: ${BumpType.names}.');
    }
  }

  @override
  bool confirmRelease() {
    if (!isInteractive) return false;

    stdout.write('\nProceed with release? [y/N] ');
    final reply = stdin.readLineSync()?.trim().toLowerCase() ?? '';

    return reply == 'y' || reply == 'yes';
  }
}
