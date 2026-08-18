import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';
import 'package:minted_network/minted_network.dart';

import 'support/bdd.dart';

void main() {
  feature('Port', () {
    // The expected `.value` doubles as the outcome; null means the input was rejected.
    scenarioOutline<({int input, int? value})>(
      'Port.tryFrom accepts the whole 16-bit range and refuses either side of it',
      examples: {
        'zero, accepted and reported by range rather than refused': (input: 0, value: 0),
        'the lowest user port': (input: 1024, value: 1024),
        'the ceiling': (input: 65535, value: 65535),
        'one past the ceiling': (input: 65536, value: null),
        'negative': (input: -1, value: null),
      },
      outline: (example) {
        check(Port.tryFrom(example.input)?.value).equals(example.value);
      },
    );

    // RFC 6335 §6 fixes these three ranges, so the boundaries are the interesting cases.
    scenarioOutline<({int input, PortRange range})>(
      'range reports the RFC 6335 band, checked at every boundary',
      examples: {
        'zero is a system port': (input: 0, range: .system),
        'the last system port': (input: 1023, range: .system),
        'the first user port': (input: 1024, range: .user),
        'the last user port': (input: 49151, range: .user),
        'the first dynamic port': (input: 49152, range: .dynamic),
        'the last dynamic port': (input: 65535, range: .dynamic),
        'https, a well-known port': (input: 443, range: .system),
      },
      outline: (example) {
        check(Port.tryFrom(example.input)!.range).equals(example.range);
      },
    );

    scenario('only port 0 is the wildcard', () {
      check(Port.tryFrom(0)!.isWildcard).isTrue();
      check(Port.tryFrom(1)!.isWildcard).isFalse();
      check(Port.tryFrom(65535)!.isWildcard).isFalse();
    });

    // A Port is a Uint16, so it widens without a hop. The reverse is a compile error, which a
    // runtime test cannot express.
    scenario('a Port goes where a Uint16 is wanted', () {
      final Uint16 widened = Port.tryFrom(443)!;

      check(widened).equals(Uint16.tryFrom(443)!);
    });

    scenario('a Port renders as its bare number', () {
      check(Port.tryFrom(8080)!.toString()).equals('8080');
    });

    scenario('equality is by value', () {
      check(Port.tryFrom(443)!).equals(Port.tryFrom(443)!);
      check(Port.tryFrom(443)! == Port.tryFrom(80)!).isFalse();
    });
  });
}
