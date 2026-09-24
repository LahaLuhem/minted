/// Where the workspace sits on disk, for suites that read the repo rather than call into it.
library;

import 'dart:io';

/// The directory holding `packages/`, found by climbing until the workspace pubspec turns up.
///
/// Not `Directory('..')`: that lands wherever the suite was launched from, and from the repo root it
/// walked whatever sat beside the repo.
String workspaceRoot() {
  for (var directory = Directory.current; ; directory = directory.parent) {
    final pubspec = File('${directory.path}/pubspec.yaml');
    if (pubspec.existsSync() && pubspec.readAsStringSync().contains('\nworkspace:')) {
      return directory.path;
    }
    if (directory.path == directory.parent.path) {
      throw StateError('No workspace pubspec above ${Directory.current.path}.');
    }
  }
}

/// Every member's `lib/`, or the named subdirectory of it where one is given.
Iterable<Directory> memberDirectories([String subdirectory = '']) =>
    Directory('${workspaceRoot()}/packages')
        .listSync()
        .whereType<Directory>()
        .map((package) => Directory('${package.path}/lib$subdirectory'));
