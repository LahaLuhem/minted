import 'dart:convert';
import 'dart:io';

import '../parsing/changelog.dart';
import '../parsing/pubspec_fields.dart';
import '../release_abort.dart';

/// A workspace member that is publishable and has notes waiting.
typedef PendingPackage = ({String dir, String name});

/// One container-based lint check, as the shared manifest declares it.
typedef LintCheck = ({String name, String cmd});

/// The checkout the release runs against, and every read it needs from disk.
///
/// Arguments and return values are repo-relative, since they end up in git arguments and messages.
class Repo {
  const new(this.root);

  /// Absolute path to the workspace root.
  final String root;

  /// Shared with repo.yml, so both gates run the identical check set.
  static const lintManifestPath = '.github/lint-checks.json';

  /// The branch a release may be cut from.
  static const mainBranch = 'main';

  String absolute(String relative) => '$root/$relative';

  String readFile(String relative) => File(absolute(relative)).readAsStringSync();

  bool fileExists(String relative) => File(absolute(relative)).existsSync();

  /// Every member directory under `packages/`, sorted because the picker numbers what it lists.
  List<String> memberDirs() {
    final packages = Directory(absolute('packages'));
    if (!packages.existsSync()) return const [];

    // `toList(growable: false)..sort()` rather than `sorted()`: one allocation, and sorting only
    // assigns elements, which a fixed-length list allows.
    return packages
        .listSync()
        .whereType<Directory>()
        .map((member) => 'packages/${member.path.split('/').last}')
        .where((member) => fileExists('$member/pubspec.yaml'))
        .toList(growable: false)
      ..sort();
  }

  /// Each member's declared name mapped to its pubspec text, private members included: they declare
  /// no version, so the constraint guard drops them anyway.
  Map<String, String> memberPubspecs() => Map.fromEntries(
    memberDirs().map((dir) => readFile('$dir/pubspec.yaml')).map(_namedEntry).nonNulls,
  );

  /// [pubspec] keyed by the name it declares, or null when it declares none.
  static MapEntry<String, String>? _namedEntry(String pubspec) {
    final name = pubspecName(pubspec);

    return name == null ? null : MapEntry(name, pubspec);
  }

  /// Publishable members with notes waiting. cider dates the heading on release, so a package drops
  /// off this list by construction once it ships.
  List<PendingPackage> pendingPackages() =>
      memberDirs().map(_candidateAt).nonNulls.toList(growable: false);

  /// [dir] as a release candidate, or null when it is private, undocumented, or already shipped.
  PendingPackage? _candidateAt(String dir) {
    if (!fileExists('$dir/CHANGELOG.md')) return null;

    final pubspec = readFile('$dir/pubspec.yaml');
    final name = pubspecName(pubspec);
    if (name == null || publishesToNone(pubspec)) return null;

    return hasUnreleasedNotes(readFile('$dir/CHANGELOG.md')) ? (dir: dir, name: name) : null;
  }

  /// The lint image and checks. Aborts rather than returning empty, so an unreadable manifest
  /// cannot silently skip every lint.
  ({String image, List<LintCheck> checks}) lintManifest() {
    const malformed = '$lintManifestPath is missing, malformed, or has no checks.';

    if (!fileExists(lintManifestPath)) throw ReleaseAbort(malformed);

    final Object? parsed;
    try {
      parsed = jsonDecode(readFile(lintManifestPath));
    } on FormatException {
      // A jsonDecode trace says nothing about the manifest the user must fix.
      // ignore: avoid-throw-in-catch-block
      throw ReleaseAbort(malformed);
    }

    return switch (parsed) {
      {'image': final String image, 'checks': final List<Object?> checks}
          when image.isNotEmpty && checks.isNotEmpty =>
        (image: image, checks: checks.map(_lintCheckFrom).toList(growable: false)),
      _ => throw ReleaseAbort(malformed),
    };
  }

  /// One manifest entry. Declared order is kept: it is the order the checks run in.
  static LintCheck _lintCheckFrom(Object? check) => switch (check) {
    {'name': final String name, 'cmd': final String cmd} => (name: name, cmd: cmd),
    _ => throw ReleaseAbort('$lintManifestPath has a malformed check entry.'),
  };
}
