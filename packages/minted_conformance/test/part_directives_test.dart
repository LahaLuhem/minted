// Named for the rule rather than for a declaration, of which it has none.
// ignore_for_file: prefer-match-file-name

import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../../test/support/workspace.dart';

/// Refuses any `import`, `export` or `@docImport` pointing at a file that is a `part of` something,
/// which crashes `dart analyze` rather than being reported:
/// https://github.com/dart-lang/sdk/issues/56013#issuecomment-5757258757
void main() {
  // Regex rather than the AST: a doc import lives inside a doc comment, and how the analyzer hands
  // that over moves between versions.
  final directive = RegExp(
    r'''^(?:///\s*@docImport|import|export)\s+'([^']+)';''',
    multiLine: true,
  );
  final partOf = RegExp(r"""^part\s+of\s+['"]""", multiLine: true);

  final sources = memberDirectories()
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

    check(offenders, because: 'point at the file that declares the part instead').isEmpty();
  });
}

/// Where [target] lands on disk, or null for the SDK and anything outside the workspace.
Uri? _resolve(String target, File source) {
  if (target.startsWith('dart:')) return null;

  if (target.startsWith('package:')) {
    final [package, ...path] = target.replaceFirst('package:', '').split('/');

    return File('${workspaceRoot()}/packages/$package/lib/${path.join('/')}').absolute.uri
        .normalizePath();
  }

  return source.parent.uri.resolve(target).normalizePath();
}
