import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('IpAddress', () {
    // The canonical form doubles as the expected outcome; null means rejected. Addresses come from
    // the documentation ranges RFC 5737 and RFC 3849 reserve, and the shapes from RFC 5952 §4.
    scenarioOutline<({String input, String? canonical})>(
      'IpAddress.tryParse accepts both families, canonicalises them, and rejects the rest',
      examples: {
        'a dotted quad': (input: '192.0.2.1', canonical: '192.0.2.1'),
        'surrounding whitespace is trimmed': (input: '  198.51.100.1  ', canonical: '198.51.100.1'),
        'the unspecified and loopback v4 addresses': (input: '0.0.0.0', canonical: '0.0.0.0'),
        'a single zero octet is not a leading zero': (
          input: '203.0.113.0',
          canonical: '203.0.113.0',
        ),
        'v6 leading zeros are suppressed': (input: '2001:0db8::0001', canonical: '2001:db8::1'),
        'v6 uppercase is lower-cased': (input: '2001:DB8::1', canonical: '2001:db8::1'),
        'the longest zero run is compressed': (
          input: '2001:db8:0:0:0:0:2:1',
          canonical: '2001:db8::2:1',
        ),
        'a single zero field is never compressed': (
          input: '2001:db8:0:1:1:1:1:1',
          canonical: '2001:db8:0:1:1:1:1:1',
        ),
        'the first of two equal zero runs wins': (
          input: '2001:DB8:0:0:1:0:0:1',
          canonical: '2001:db8::1:0:0:1',
        ),
        'the unspecified address': (input: '::', canonical: '::'),
        'the v6 loopback': (input: '::1', canonical: '::1'),
        'a v4-mapped address keeps its mixed spelling': (
          input: '::ffff:192.0.2.1',
          canonical: '::ffff:192.0.2.1',
        ),
        'a v4-mapped address written in hex gains the mixed spelling': (
          input: '0:0:0:0:0:ffff:c000:201',
          canonical: '::ffff:192.0.2.1',
        ),
        'ffff outside the mapped prefix is not mixed-rendered': (
          input: '0:0:0:0:ffff:0:0:0',
          canonical: '::ffff:0:0:0',
        ),
        'a leading zero is rejected, not read as octal': (input: '192.168.010.1', canonical: null),
        'a signed octet is rejected, though int.parse would take it': (
          input: '192.168.+1.1',
          canonical: null,
        ),
        'a negative zero octet is rejected': (input: '192.168.-0.1', canonical: null),
        'internal whitespace is rejected': (input: '192.168. 1.1', canonical: null),
        'a signed hextet is rejected': (input: '2001:+db8::1', canonical: null),
        'an octet past 255 is rejected': (input: '192.0.2.256', canonical: null),
        'three octets is not an address': (input: '192.0.2', canonical: null),
        'five octets is not an address': (input: '1.2.3.4.5', canonical: null),
        'a five-digit hextet is rejected': (input: '12345::1', canonical: null),
        'a triple colon is rejected': (input: '2001:db8:::1', canonical: null),
        'two compressions are rejected': (input: '2001::db8::1', canonical: null),
        'the integer spelling of an address is rejected': (input: '3221225985', canonical: null),
        'an empty string is rejected': (input: '', canonical: null),
      },
      outline: (example) {
        check(IpAddress.tryParse(example.input)?.value).equals(example.canonical);
      },
    );

    scenarioOutline<({String input, IpAddressFailure failure})>(
      'IpAddress.parse attributes the failure',
      examples: {
        'an octal-ambiguous octet is named, not lumped in with junk': (
          input: '192.168.010.1',
          failure: const IpAddressLeadingZero('010'),
        ),
        'a leading zero in a mapped tail is caught too': (
          input: '::ffff:192.168.010.1',
          failure: const IpAddressLeadingZero('010'),
        ),
        'an octet past its field echoes it': (
          input: '192.0.2.256',
          failure: const IpAddressPartOutOfRange('256'),
        ),
        'a hextet past its field echoes it': (
          input: '12345::1',
          failure: const IpAddressPartOutOfRange('12345'),
        ),
        'anything else is malformed': (
          input: 'not-an-address',
          failure: const IpAddressMalformed(),
        ),
      },
      outline: (example) {
        check(IpAddress.parse(example.input).reasonOrNull).equals(example.failure);
      },
    );

    scenario('version reports the family, and the two never compare equal', () {
      final v4 = IpAddress.tryParse('192.0.2.1')!;
      final v6 = IpAddress.tryParse('2001:db8::1')!;

      check(v4.version).equals(IpVersion.v4);
      check(v6.version).equals(IpVersion.v6);
      check(v4 == v6).isFalse();
      // A mapped address is v6, whatever its tail looks like.
      check(IpAddress.tryParse('::ffff:192.0.2.1')!.version).equals(IpVersion.v6);
    });

    scenario('octets and fromOctets round-trip in both families', () {
      final v4 = IpAddress.tryParse('192.0.2.1')!;
      final v6 = IpAddress.tryParse('2001:db8::1')!;

      check(v4.octets).deepEquals([192, 0, 2, 1]);
      check(v6.octets.length).equals(16);
      check(IpAddress.fromOctets(v4.octets).getOrThrow()).equals(v4);
      check(IpAddress.fromOctets(v6.octets).getOrThrow()).equals(v6);
    });

    scenario('fromOctets reports a failure unless there are 4 or 16 octets', () {
      check(IpAddress.fromOctets(Uint8List(5)).isFailure).isTrue();
      check(IpAddress.fromOctets(Uint8List(15)).isFailure).isTrue();
      check(IpAddress.fromOctets(Uint8List(4)).getOrThrow().value).equals('0.0.0.0');
      check(IpAddress.fromOctets(Uint8List(16)).getOrThrow().value).equals('::');
    });

    scenario('isLoopback covers 127.0.0.0/8 and ::1, and nothing else', () {
      check(IpAddress.tryParse('127.0.0.1')!.isLoopback).isTrue();
      check(IpAddress.tryParse('127.255.255.254')!.isLoopback).isTrue();
      check(IpAddress.tryParse('::1')!.isLoopback).isTrue();
      check(IpAddress.tryParse('128.0.0.1')!.isLoopback).isFalse();
      check(IpAddress.tryParse('2001:db8::1')!.isLoopback).isFalse();
    });

    scenario('isPrivate covers the RFC 1918 blocks and RFC 4193 unique local addresses', () {
      check(IpAddress.tryParse('10.0.0.1')!.isPrivate).isTrue();
      check(IpAddress.tryParse('172.16.0.1')!.isPrivate).isTrue();
      check(IpAddress.tryParse('172.31.255.254')!.isPrivate).isTrue();
      check(IpAddress.tryParse('192.168.1.1')!.isPrivate).isTrue();
      check(IpAddress.tryParse('fc00::1')!.isPrivate).isTrue();
      check(IpAddress.tryParse('fd00::1')!.isPrivate).isTrue();
      // The blocks' edges: 172.15 and 172.32 are public, and fe00:: is outside fc00::/7.
      check(IpAddress.tryParse('172.15.0.1')!.isPrivate).isFalse();
      check(IpAddress.tryParse('172.32.0.1')!.isPrivate).isFalse();
      check(IpAddress.tryParse('fe00::1')!.isPrivate).isFalse();
      check(IpAddress.tryParse('192.0.2.1')!.isPrivate).isFalse();
    });

    scenario('compareTo orders numerically within a family, and v4 before v6', () {
      // Lexicographic ordering would put .10 before .9, which is the bug this guards.
      final ninth = IpAddress.tryParse('192.0.2.9')!;
      final tenth = IpAddress.tryParse('192.0.2.10')!;

      check(ninth.compareTo(tenth)).isLessThan(0);
      check(tenth.compareTo(ninth)).isGreaterThan(0);
      check(ninth.compareTo(IpAddress.tryParse('2001:db8::1')!)).isLessThan(0);
      // Within v6 too, where '::9' sorts lexicographically after '::10' but numerically before it.
      check(IpAddress.tryParse('2001:db8::9')!.compareTo(IpAddress.tryParse('2001:db8::10')!))
          .isLessThan(0);
      // Comparator test
      // ignore: avoid-passing-self-as-argument
      check(ninth.compareTo(ninth)).equals(0);
    });

    scenario('equal addresses are equal, whichever spelling they are built from', () {
      final canonical = IpAddress.tryParse('2001:db8::1')!;

      check(IpAddress.tryParse('2001:0DB8:0:0:0:0:0:1')!).equals(canonical);
      check(IpAddress.tryParse('  2001:DB8::1  ')!).equals(canonical);
    });

    scenario('parse reports the failure rather than throwing', () {
      check(IpAddress.parse('not-an-address')).equals(const ParseFailure(IpAddressMalformed()));
      check(IpAddress.parse('192.0.2.1').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(IpAddress.tryParse('not-an-address')).isNull();
      check(IpAddress.tryParse('192.0.2.1')?.value).equals('192.0.2.1');
    });

    scenario('the failure names the type, not its erased representation', () {
      // Extension types erase to String at runtime, so a `<T>`-derived name would read "String".
      check(IpAddress.parse('nope').reasonOrNull?.typeName).equals('IpAddress');
      check(IpAddress.fromOctets(Uint8List(5)).reasonOrNull?.message)
          .equals('expected 4 or 16 octets, got 5');
    });
  });
}
