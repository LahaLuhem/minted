import 'package:collection/collection.dart';

import '../parsing/pubspec_fields.dart';

/// Which part of a SemVer version a release moves.
enum BumpType {
  major,
  minor,
  patch;

  static BumpType? tryParse(String name) => values.firstWhereOrNull((bump) => bump.name == name);

  /// Every name a caller may pass, for the usage text and the error paths.
  static String get names => values.map((bump) => bump.name).join(', ');

  /// The version this bump produces from [current].
  ///
  /// Pre-release and build metadata are dropped, matching cider, so the two can cross-check.
  String applyTo(String current) {
    if (!semverPattern.hasMatch(current)) {
      throw ArgumentError.value(current, 'current', 'not a SemVer version');
    }

    final [major, minor, patch] = current
        .split(RegExp('[-+]'))
        .first
        .split('.')
        .map(int.parse)
        .toList(growable: false);

    return switch (this) {
      .major => '${major + 1}.0.0',
      .minor => '$major.${minor + 1}.0',
      .patch => '$major.$minor.${patch + 1}',
    };
  }
}
