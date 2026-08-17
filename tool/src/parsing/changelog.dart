import 'dart:convert';

/// The unreleased heading, with or without the link brackets.
final _unreleasedHeading = RegExp(r'^## \[?unreleased\]?', caseSensitive: false);

final _punctuationOnly = RegExp(r'[\s-]');

bool _isHeading(String line) => line.startsWith('## ');

/// Notes under [changelog]'s first `## ` heading, when that heading is `## Unreleased`.
///
/// Only the first heading counts: a dated one on top means the last release consumed everything
/// below it. Empty for anything else, so "nothing here" reads as "nothing to release".
String unreleasedNotes(String changelog) {
  final lines = const LineSplitter().convert(changelog);
  final opening = lines.indexWhere(_isHeading);
  if (opening < 0 || !_unreleasedHeading.hasMatch(lines[opening])) return '';

  return lines.skip(opening + 1).takeWhile((line) => !_isHeading(line)).join('\n');
}

/// Whether [changelog]'s unreleased block holds anything beyond bullet punctuation: a block of bare
/// `-` markers is as empty as no block at all.
bool hasUnreleasedNotes(String changelog) =>
    unreleasedNotes(changelog).replaceAll(_punctuationOnly, '').isNotEmpty;
