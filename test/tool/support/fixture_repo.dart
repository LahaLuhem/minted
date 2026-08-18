import 'dart:io';

import '../../../tool/src/io/repo.dart';

/// A throwaway workspace on disk, holding only the files the release flow reads: no lib, no git.
class FixtureRepo {
  new() : _root = Directory.systemTemp.createTempSync('minted_release_');

  final Directory _root;

  Repo get repo => Repo(_root.path);

  /// Writes a member with [name] at `packages/<dir>`, defaulting the directory to the name.
  void addMember({
    required String name,
    String? dir,
    String? version,
    String changelog = '## Unreleased\n- Something worth releasing.\n',
    Map<String, String> dependencies = const {},
    bool publishable = true,
  }) {
    final target = Directory('${_root.path}/packages/${dir ?? name}')..createSync(recursive: true);

    final pubspec = [
      'name: $name',
      if (version != null) 'version: $version',
      if (!publishable) 'publish_to: none',
      if (dependencies.isNotEmpty) 'dependencies:',
      ...dependencies.entries.map((entry) => '  ${entry.key}: ${entry.value}'),
    ].join('\n');

    File('${target.path}/pubspec.yaml').writeAsStringSync('$pubspec\n');
    File('${target.path}/CHANGELOG.md').writeAsStringSync(changelog);
  }

  /// Writes the lint manifest the preflight reads.
  void addLintManifest({String checks = '{ "name": "actionlint", "cmd": "actionlint" }'}) {
    Directory('${_root.path}/.github').createSync(recursive: true);
    File('${_root.path}/.github/${Repo.lintManifestPath.split('/').last}')
        .writeAsStringSync('{ "image": "ghcr.io/example/linterpol:latest", "checks": [$checks] }');
  }

  void dispose() => _root.deleteSync(recursive: true);
}
