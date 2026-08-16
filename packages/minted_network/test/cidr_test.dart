import 'package:checks/checks.dart';
import 'package:minted/minted.dart';
import 'package:minted_network/minted_network.dart';

import 'support/bdd.dart';

void main() {
  feature('Cidr', () {
    // The canonical form doubles as the expected outcome; null means rejected. Blocks come from the
    // documentation ranges RFC 5737 and RFC 3849 reserve, plus the RFC 1918 ones people use.
    scenarioOutline<({String input, String? canonical})>(
      'Cidr.tryParse accepts well-formed blocks and rejects the rest',
      examples: {
        'an RFC 1918 block': (input: '10.0.0.0/8', canonical: '10.0.0.0/8'),
        'a documentation block': (input: '192.0.2.0/24', canonical: '192.0.2.0/24'),
        'a single-host v4 block': (input: '192.0.2.1/32', canonical: '192.0.2.1/32'),
        'the whole v4 space': (input: '0.0.0.0/0', canonical: '0.0.0.0/0'),
        'a v6 block': (input: '2001:db8::/32', canonical: '2001:db8::/32'),
        'a v6 block is canonicalised through its address': (
          input: '2001:0DB8:0000::/32',
          canonical: '2001:db8::/32',
        ),
        'a single-host v6 block': (input: '2001:db8::1/128', canonical: '2001:db8::1/128'),
        'the whole v6 space': (input: '::/0', canonical: '::/0'),
        'surrounding whitespace is trimmed': (input: '  10.0.0.0/8  ', canonical: '10.0.0.0/8'),
        'a non-byte-aligned prefix': (input: '198.51.100.128/25', canonical: '198.51.100.128/25'),
        'host bits set is rejected, not masked': (input: '192.168.1.5/24', canonical: null),
        'host bits set in v6 is rejected too': (input: '2001:db8::1/32', canonical: null),
        'a prefix past the v4 width is rejected': (input: '192.0.2.0/33', canonical: null),
        'a v4 prefix on a v6 address is not a v6 limit': (input: '2001:db8::/129', canonical: null),
        'a dotted netmask is rejected, though the engine takes it': (
          input: '192.168.1.0/255.255.255.0',
          canonical: null,
        ),
        'a bare address invents no prefix': (input: '192.0.2.1', canonical: null),
        'a signed prefix is rejected': (input: '192.0.2.0/+24', canonical: null),
        'a negative prefix is rejected': (input: '192.0.2.0/-1', canonical: null),
        'a leading zero in the address is still refused': (
          input: '192.168.010.0/24',
          canonical: null,
        ),
        'two slashes is not a block': (input: '10.0.0.0/8/8', canonical: null),
        'an empty string is rejected': (input: '', canonical: null),
      },
      outline: (example) {
        check(Cidr.tryParse(example.input)?.asString).equals(example.canonical);
      },
    );

    scenarioOutline<({String input, CidrFailure failure})>(
      'Cidr.parse attributes the failure',
      examples: {
        'host bits set offers the block that was meant': (
          input: '192.168.1.5/24',
          failure: const CidrHostBitsSet('192.168.1.0/24'),
        ),
        'a prefix past the family width names the width': (
          input: '192.0.2.0/33',
          failure: const CidrPrefixLengthOutOfRange(maxPrefixLength: 32, actual: 33),
        ),
        'the v6 width is 128, not 32': (
          input: '2001:db8::/129',
          failure: const CidrPrefixLengthOutOfRange(maxPrefixLength: 128, actual: 129),
        ),
        "a bad address keeps the address type's own reason": (
          input: '192.168.010.0/24',
          failure: const CidrInvalidAddress(IpAddressLeadingZero('010')),
        ),
        'a missing prefix is malformed': (input: '192.0.2.1', failure: const CidrMalformed()),
        'a non-numeric prefix is malformed': (
          input: '192.168.1.0/255.255.255.0',
          failure: const CidrMalformed(),
        ),
      },
      outline: (example) {
        check(Cidr.parse(example.input).reasonOrNull).equals(example.failure);
      },
    );

    // The nesting is the point: a caller learns the address had a leading zero, not merely that
    // something about it was wrong.
    scenario('the nested address failure survives into the message', () {
      check(Cidr.parse('192.168.010.0/24').reasonOrNull?.message).equals(
        'the network address is invalid: "010" has a leading zero, '
        'which is ambiguous between decimal and octal',
      );
      check(Cidr.parse('nonsense/24').reasonOrNull).isA<CidrInvalidAddress>();
    });

    scenario('the parts are typed, not sliced back out of the text', () {
      final block = Cidr.tryParse('192.0.2.0/24')!;

      check(block.network).equals(IpAddress.tryParse('192.0.2.0')!);
      check(block.network.version).equals(IpVersion.v4);
      check(block.prefixLength).equals(24);
    });

    scenarioOutline<({String block, String address, bool contained})>(
      'Cidr.contains tests the network part, not the text',
      examples: {
        'an address inside a byte-aligned block': (
          block: '10.0.0.0/8',
          address: '10.1.2.3',
          contained: true,
        ),
        'the network address itself is inside': (
          block: '10.0.0.0/8',
          address: '10.0.0.0',
          contained: true,
        ),
        'the last address is inside': (
          block: '10.0.0.0/8',
          address: '10.255.255.255',
          contained: true,
        ),
        'one past the end is outside': (block: '10.0.0.0/8', address: '11.0.0.0', contained: false),
        // A text prefix match would call this contained, which is the bug the type exists for.
        'a textual prefix match is not containment': (
          block: '10.0.0.0/8',
          address: '100.0.0.1',
          contained: false,
        ),
        'a non-byte-aligned block splits the octet': (
          block: '198.51.100.128/25',
          address: '198.51.100.200',
          contained: true,
        ),
        'and excludes the half below it': (
          block: '198.51.100.128/25',
          address: '198.51.100.127',
          contained: false,
        ),
        'a /32 contains only itself': (
          block: '192.0.2.1/32',
          address: '192.0.2.1',
          contained: true,
        ),
        'a /32 excludes its neighbour': (
          block: '192.0.2.1/32',
          address: '192.0.2.2',
          contained: false,
        ),
        'a /0 contains everything in its family': (
          block: '0.0.0.0/0',
          address: '203.0.113.9',
          contained: true,
        ),
        'a v6 block contains a v6 address': (
          block: '2001:db8::/32',
          address: '2001:db8:1234::1',
          contained: true,
        ),
        'a v6 block excludes a neighbouring prefix': (
          block: '2001:db8::/32',
          address: '2001:db9::1',
          contained: false,
        ),
        // The cost of one type for both families: this compiles, and answers false.
        'a v6 address is never inside a v4 block': (
          block: '10.0.0.0/8',
          address: '::1',
          contained: false,
        ),
        'a v4 address is never inside a v6 block': (
          block: '2001:db8::/32',
          address: '10.0.0.1',
          contained: false,
        ),
      },
      outline: (example) {
        check(Cidr.tryParse(example.block)!.contains(IpAddress.tryParse(example.address)!))
            .equals(example.contained);
      },
    );

    scenarioOutline<({String block, String last})>(
      'Cidr.lastAddress is the top of the block',
      examples: {
        'a byte-aligned v4 block': (block: '10.0.0.0/8', last: '10.255.255.255'),
        'a non-byte-aligned v4 block': (block: '198.51.100.128/25', last: '198.51.100.255'),
        'a /32 is its own last address': (block: '192.0.2.1/32', last: '192.0.2.1'),
        'the whole v4 space': (block: '0.0.0.0/0', last: '255.255.255.255'),
        'a v6 block': (block: '2001:db8::/32', last: '2001:db8:ffff:ffff:ffff:ffff:ffff:ffff'),
        'a /128 is its own last address': (block: '2001:db8::1/128', last: '2001:db8::1'),
      },
      outline: (example) {
        check(Cidr.tryParse(example.block)!.lastAddress).equals(IpAddress.tryParse(example.last)!);
      },
    );

    scenario('from builds from typed parts and throws when they do not form a block', () {
      final network = IpAddress.tryParse('192.0.2.0')!;

      check(Cidr.from(network: network, prefixLength: 24).getOrThrow().asString)
          .equals('192.0.2.0/24');
      check(Cidr.from(network: IpAddress.tryParse('192.0.2.5')!, prefixLength: 24).reasonOrNull)
          .isA<CidrHostBitsSet>();
      check(Cidr.from(network: network, prefixLength: 33).reasonOrNull)
          .isA<CidrPrefixLengthOutOfRange>();
    });

    scenario('equal blocks are equal by value and hash, and differ by either part', () {
      final block = Cidr.tryParse('192.0.2.0/24')!;

      check(Cidr.tryParse('192.0.2.0/24')!).equals(block);
      check(Cidr.tryParse('192.0.2.0/24')!.hashCode).equals(block.hashCode);
      check(Cidr.tryParse('192.0.2.0/25') == block).isFalse();
      check(Cidr.tryParse('198.51.100.0/24') == block).isFalse();
    });

    scenario('toString names both parts, unlike the canonical form', () {
      final block = Cidr.tryParse('192.0.2.0/24')!;

      check(block.toString()).equals('Cidr(network: 192.0.2.0, prefixLength: 24)');
      check(block.asString).equals('192.0.2.0/24');
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Cidr.parse('192.168.1.5/24'))
          .equals(const ParseFailure(CidrHostBitsSet('192.168.1.0/24')));
      check(Cidr.parse('10.0.0.0/8').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Cidr.tryParse('192.168.1.5/24')).isNull();
      check(Cidr.tryParse('10.0.0.0/8')?.asString).equals('10.0.0.0/8');
    });

    scenario('the failure names the type', () {
      check(Cidr.parse('nope').reasonOrNull?.typeName).equals('Cidr');
      check(
        Cidr.from(
          network: IpAddress.tryParse('192.0.2.5')!,
          prefixLength: 24,
        ).reasonOrNull?.typeName,
      ).equals('Cidr');
    });
  });
}
