import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../../tool/src/parsing/pubspec_fields.dart';

void main() {
  group('field reads', () {
    test('reads the declared name and version', () {
      const pubspec = 'name: minted\nversion: 3.0.0\n';

      check(pubspecName(pubspec)).equals('minted');
      check(pubspecVersion(pubspec)).equals('3.0.0');
      check(pubspecMajor(pubspec)).equals(3);
    });

    test('takes the first match, so a later nested key cannot win', () {
      const pubspec = 'name: minted\nversion: 3.0.0\ncider:\n  name: not_the_package\n';

      check(pubspecName(pubspec)).equals('minted');
    });

    test('a missing field reads as null rather than empty', () {
      check(pubspecVersion('name: minted_conformance\n')).isNull();
      check(pubspecMajor('name: minted_conformance\n')).isNull();
    });

    test('a pre-release version still yields its major', () {
      check(pubspecMajor('version: 3.0.0-beta.1\n')).equals(3);
    });
  });

  group('publishesToNone', () {
    test('is true for a private member', () {
      check(publishesToNone('name: x\npublish_to: none\n')).isTrue();
    });

    test('tolerates the extra space pub allows', () {
      check(publishesToNone('name: x\npublish_to:  none\n')).isTrue();
    });

    test('is false when the key is absent', () {
      check(publishesToNone('name: x\nversion: 1.0.0\n')).isFalse();
    });
  });

  group('dependencyLine and constraintOf', () {
    const pubspec = '''
name: minted_contact
version: 1.0.0
dependencies:
  minted: ^3.0.0
  minted_network: '>=1.0.0 <2.0.0'
''';

    test('finds a dependency at the nesting level pub uses', () {
      check(dependencyLine(pubspec, 'minted')).equals('  minted: ^3.0.0');
    });

    // `minted` must not match the `minted_network` line, or the guard reads the wrong constraint.
    test('does not match a dependency whose name merely starts the same', () {
      check(dependencyLine(pubspec, 'minted_network')).equals("  minted_network: '>=1.0.0 <2.0.0'");
    });

    test('an undeclared dependency reads as null', () {
      check(dependencyLine(pubspec, 'minted_finance')).isNull();
    });

    test('strips the name off a caret constraint', () {
      check(constraintOf('  minted: ^3.0.0')).equals('^3.0.0');
    });

    test('strips the name off a ranged constraint', () {
      check(constraintOf("  minted: '>=2.0.0 <4.0.0'")).equals("'>=2.0.0 <4.0.0'");
    });
  });

  group('staleConstraints', () {
    // The case the guard exists for: a sibling still claiming the pre-split major.
    test('flags a lower bound older than the major the tree builds', () {
      final stale = staleConstraints(
        selectedName: 'minted_contact',
        selectedPubspec: "name: minted_contact\ndependencies:\n  minted: '>=2.0.0 <4.0.0'\n",
        memberPubspecs: {'minted': 'name: minted\nversion: 3.0.0\n'},
      );

      check(stale).length.equals(1);
      check(stale.single.member).equals('minted');
      check(stale.single.treeMajor).equals(3);
    });

    test('accepts a constraint that matches the tree', () {
      final stale = staleConstraints(
        selectedName: 'minted_contact',
        selectedPubspec: 'name: minted_contact\ndependencies:\n  minted: ^3.0.0\n',
        memberPubspecs: {'minted': 'name: minted\nversion: 3.0.0\n'},
      );

      check(stale).isEmpty();
    });

    test('accepts a constraint ahead of the tree, which resolution catches instead', () {
      final stale = staleConstraints(
        selectedName: 'minted_contact',
        selectedPubspec: 'name: minted_contact\ndependencies:\n  minted: ^4.0.0\n',
        memberPubspecs: {'minted': 'name: minted\nversion: 3.0.0\n'},
      );

      check(stale).isEmpty();
    });

    test('skips the package being released, so it cannot flag itself', () {
      final stale = staleConstraints(
        selectedName: 'minted',
        selectedPubspec: 'name: minted\nversion: 3.0.0\ndependencies:\n  minted: ^1.0.0\n',
        memberPubspecs: {'minted': 'name: minted\nversion: 3.0.0\n'},
      );

      check(stale).isEmpty();
    });

    // A private member declares no version, so there is no tree major to compare against.
    test('skips a member that declares no version', () {
      final stale = staleConstraints(
        selectedName: 'minted',
        selectedPubspec: 'name: minted\ndependencies:\n  minted_conformance: ^1.0.0\n',
        memberPubspecs: {'minted_conformance': 'name: minted_conformance\npublish_to: none\n'},
      );

      check(stale).isEmpty();
    });

    test('reports every stale constraint, not just the first', () {
      final stale = staleConstraints(
        selectedName: 'minted_contact',
        selectedPubspec: '''
name: minted_contact
dependencies:
  minted: ^2.0.0
  minted_network: ^1.0.0
''',
        memberPubspecs: {
          'minted': 'name: minted\nversion: 3.0.0\n',
          'minted_network': 'name: minted_network\nversion: 2.0.0\n',
        },
      );

      check(stale).length.equals(2);
    });
  });
}
