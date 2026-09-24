// Named for the rule rather than for a declaration, of which it has none.
// ignore_for_file: prefer-match-file-name

import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

/// Refuses any `import`, `export` or `@docImport` pointing at a file that is a `part of` something.
///
/// A part is not a library, so the analyzer is meant to report `import_of_non_library`. It crashes
/// with `Missing library` instead, and names the part rather than the file holding the bad
/// reference, which makes it slow to find by hand. Reported as
/// https://github.com/dart-lang/sdk/issues/56013#issuecomment-5757258757. It has bitten twice: once
/// when `Cidr` became a part of `ip_address.dart`, once when `ShortPlusCode` landed as a part.
///
/// Regex rather than the AST, because a doc import lives inside a doc comment and how the analyzer
/// exposes it moves between versions. The formatter keeps directives on their own lines, so there is
/// nothing here for a parser to earn.
void main() {
  final directive = RegExp(
    r'''^(?:///\s*@docImport|import|export)\s+'([^']+)';''',
    multiLine: true,
  );
  final partOf = RegExp(r"""^part\s+of\s+['"]""", multiLine: true);

  final packages = Directory('${_workspaceRoot()}/packages');
  final sources = packages
      .listSync()
      .whereType<Directory>()
      .map((package) => Directory('${package.path}/lib'))
      .where((library) => library.existsSync())
      .expand((library) => library.listSync(recursive: true))
      .whereType<File>()
      .where((entity) => entity.path.endsWith('.dart'))
      .toList();

  final parts = {
    for (final source in sources)
      if (partOf.hasMatch(source.readAsStringSync())) source.absolute.uri.normalizePath(),
  };

  test('the sweep found sources, and parts among them', () {
    check(sources).isNotEmpty();
    check(parts).isNotEmpty();
  });

  test('no directive points at a part file', () {
    final offenders = [
      for (final source in sources)
        for (final match in directive.allMatches(source.readAsStringSync()))
          if (_resolve(match.group(1)!, source) case final target? when parts.contains(target))
            '${source.path}: ${match.group(0)}',
    ];

    check(
      offenders,
      because:
          'a part is not a library, so this crashes `dart analyze` with "Missing library" rather '
          'than reporting it. Point at the file that declares the part instead.',
    ).isEmpty();
  });
}

/// The directory holding `packages/`, found by climbing until the workspace pubspec turns up.
///
/// Not `'..'`: that reads the caller's working directory, so running from the repo root sweeps
/// whatever sits beside the repo.
String _workspaceRoot() {
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

/// Where [target] lands on disk, or null for the SDK and anything outside the workspace.
Uri? _resolve(String target, File source) {
  if (target.startsWith('dart:')) return null;

  if (target.startsWith('package:')) {
    final [package, ...path] = target.replaceFirst('package:', '').split('/');

    return File('${_workspaceRoot()}/packages/$package/lib/${path.join('/')}').absolute.uri
        .normalizePath();
  }

  return source.parent.uri.resolve(target).normalizePath();
}
