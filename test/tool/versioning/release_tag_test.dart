import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../../tool/src/versioning/release_tag.dart';

void main() {
  group('releaseTag', () {
    // No `v` prefix: publish.yml routes on the package half and pub.dev matches the same pattern.
    test('joins the package and version with a hyphen', () {
      check(releaseTag(package: 'minted', version: '3.0.0')).equals('minted-3.0.0');
    });

    test('carries an underscored package name through unchanged', () {
      check(releaseTag(package: 'minted_finance', version: '1.0.1')).equals('minted_finance-1.0.1');
    });
  });

  group('splitReleaseTag', () {
    test('splits a plain tag', () {
      check(splitReleaseTag('minted-3.0.0')).equals((package: 'minted', version: '3.0.0'));
    });

    test('keeps an underscored package name whole', () {
      check(splitReleaseTag('minted_identifiers-1.0.1'))
          .equals((package: 'minted_identifiers', version: '1.0.1'));
    });

    // The reason the split is on the FIRST hyphen: pub names cannot contain one, so every later
    // hyphen belongs to the version.
    test('leaves a pre-release version intact', () {
      check(splitReleaseTag('minted-3.0.0-beta.1'))
          .equals((package: 'minted', version: '3.0.0-beta.1'));
    });

    test('round-trips whatever releaseTag builds', () {
      const package = 'minted_chronology';
      const version = '2.1.0-rc.3';

      check(splitReleaseTag(releaseTag(package: package, version: version)))
          .equals((package: package, version: version));
    });

    test('rejects a string that is not a tag', () {
      check(splitReleaseTag('minted')).isNull();
      check(splitReleaseTag('-3.0.0')).isNull();
      check(splitReleaseTag('minted-')).isNull();
    });
  });
}
