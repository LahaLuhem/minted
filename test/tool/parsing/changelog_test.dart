import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../../tool/src/parsing/changelog.dart';

void main() {
  group('unreleasedNotes', () {
    test('collects the notes under an `## Unreleased` heading', () {
      const changelog = '''
## Unreleased
### Added
- A new type.

## 1.0.0 - 2026-01-01
- The first release.
''';

      check(unreleasedNotes(changelog)).equals('### Added\n- A new type.\n');
    });

    test('accepts the bracketed link form', () {
      check(unreleasedNotes('## [Unreleased]\n- Something.\n')).equals('- Something.');
    });

    test('is case-insensitive about the heading', () {
      check(unreleasedNotes('## UNRELEASED\n- Something.\n')).equals('- Something.');
    });

    // The regression this whole function exists for: after a release, cider dates the heading, so
    // anything below it has already shipped.
    test('an `## Unreleased` below a dated heading does not count', () {
      const changelog = '''
## 2.0.0 - 2026-02-01
- Shipped.

## Unreleased
- This already went out under 2.0.0.
''';

      check(unreleasedNotes(changelog)).isEmpty();
    });

    test('stops at the next heading rather than running to the end', () {
      const changelog = '''
## Unreleased
- Mine.

## 1.0.0
- Not mine.
''';

      check(unreleasedNotes(changelog)).equals('- Mine.\n');
    });

    test('a preamble above the first heading is not notes', () {
      check(unreleasedNotes('# Changelog\n\nSome blurb.\n\n## 1.0.0\n- Shipped.\n')).isEmpty();
    });

    test('an empty changelog has no notes', () {
      check(unreleasedNotes('')).isEmpty();
    });
  });

  group('hasUnreleasedNotes', () {
    test('is true for a block with content', () {
      check(hasUnreleasedNotes('## Unreleased\n- A change.\n')).isTrue();
    });

    test('is false for a heading with nothing under it', () {
      check(hasUnreleasedNotes('## Unreleased\n\n## 1.0.0\n- Shipped.\n')).isFalse();
    });

    // A leftover bullet marker is not a note, and a package should not be offered for it.
    test('is false for bare bullet punctuation', () {
      check(hasUnreleasedNotes('## Unreleased\n-\n-  \n')).isFalse();
    });

    test('is false when the top heading is dated', () {
      check(hasUnreleasedNotes('## 1.0.0 - 2026-01-01\n- Shipped.\n')).isFalse();
    });
  });
}
