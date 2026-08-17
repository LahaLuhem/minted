import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../../tool/src/versioning/bump_type.dart';

void main() {
  group('BumpType.applyTo', () {
    test('major zeroes the minor and patch', () {
      check(BumpType.major.applyTo('3.4.5')).equals('4.0.0');
    });

    test('minor zeroes the patch', () {
      check(BumpType.minor.applyTo('3.4.5')).equals('3.5.0');
    });

    test('patch moves only the patch', () {
      check(BumpType.patch.applyTo('3.4.5')).equals('3.4.6');
    });

    test('crossing ten does not carry, since these are not decimals', () {
      check(BumpType.patch.applyTo('1.2.9')).equals('1.2.10');
      check(BumpType.minor.applyTo('1.9.0')).equals('1.10.0');
    });

    // cider does the same for a plain X.Y.Z, so the two agree and can cross-check each other.
    test('drops pre-release metadata', () {
      check(BumpType.patch.applyTo('3.0.0-beta.1')).equals('3.0.1');
    });

    test('drops build metadata', () {
      check(BumpType.minor.applyTo('3.0.0+7')).equals('3.1.0');
    });

    test('rejects anything that is not a version', () {
      check(() => BumpType.patch.applyTo('3.0')).throws<ArgumentError>();
      check(() => BumpType.patch.applyTo('not a version')).throws<ArgumentError>();
    });
  });

  group('BumpType.tryParse', () {
    test('accepts each name', () {
      check(BumpType.tryParse('major')).equals(.major);
      check(BumpType.tryParse('minor')).equals(.minor);
      check(BumpType.tryParse('patch')).equals(.patch);
    });

    test('rejects anything else, case included', () {
      check(BumpType.tryParse('Patch')).isNull();
      check(BumpType.tryParse('')).isNull();
      check(BumpType.tryParse('breaking')).isNull();
    });
  });
}
