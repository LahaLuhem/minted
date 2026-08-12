import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('MacAddress', () {
    // The canonical form doubles as the expected outcome; null means rejected. Vectors are the
    // documentation ranges RFC 9542 §2.1.4 reserves, plus the IEEE RA's own worked examples.
    scenarioOutline<({String input, String? canonical})>(
      'MacAddress.tryParse accepts the four notations, folds them, and rejects the rest',
      examples: {
        'a canonical colon-separated address': (
          input: '00:00:5e:00:53:00',
          canonical: '00:00:5e:00:53:00',
        ),
        'uppercase is lower-cased': (input: '00:00:5E:00:53:00', canonical: '00:00:5e:00:53:00'),
        'mixed case is lower-cased': (input: '00:00:5e:00:53:AB', canonical: '00:00:5e:00:53:ab'),
        'the IEEE hyphen form folds to colons': (
          input: 'AC-DE-48-23-45-67',
          canonical: 'ac:de:48:23:45:67',
        ),
        'the Cisco dot-quad form folds to colons': (
          input: 'acde.4823.4567',
          canonical: 'ac:de:48:23:45:67',
        ),
        'bare hex folds to colons': (input: 'acde48234567', canonical: 'ac:de:48:23:45:67'),
        'surrounding whitespace is trimmed': (
          input: '  00:00:5e:00:53:00  ',
          canonical: '00:00:5e:00:53:00',
        ),
        'the broadcast address': (input: 'FF:FF:FF:FF:FF:FF', canonical: 'ff:ff:ff:ff:ff:ff'),
        'the all-zero address is a real universal unicast address, not a sentinel': (
          input: '00:00:00:00:00:00',
          canonical: '00:00:00:00:00:00',
        ),
        'an IEEE 802.1 group address': (input: '01-80-C2-00-00-0E', canonical: '01:80:c2:00:00:0e'),
        'a 64-bit address keeps all eight octets': (
          input: '00:00:5e:10:00:00:00:00',
          canonical: '00:00:5e:10:00:00:00:00',
        ),
        'a 64-bit address in bare hex': (
          input: '00005E1000000000',
          canonical: '00:00:5e:10:00:00:00:00',
        ),
        'a 64-bit address in dot-quad': (
          input: '0000.5e10.0000.0000',
          canonical: '00:00:5e:10:00:00:00:00',
        ),
        'five octets is rejected': (input: '00:00:5e:00:53', canonical: null),
        'seven octets is rejected': (input: '00:00:5e:00:53:00:12', canonical: null),
        'a lone octet is rejected': (input: '00', canonical: null),
        'mixed separators are rejected': (input: '00-00:5e-00:53-00', canonical: null),
        'a trailing separator is rejected': (input: '00:00:5e:00:53:00:', canonical: null),
        'omitted leading zeros are rejected': (input: '0:0:5e:0:53:0', canonical: null),
        'odd-length bare hex is rejected': (input: '00005e00530', canonical: null),
        'a non-hex digit is rejected': (input: '00:00:5g:00:53:00', canonical: null),
        'a 0x prefix is rejected': (input: '0x00005e005300', canonical: null),
        'internal whitespace is rejected': (input: '00:00:5e:00 :53:00', canonical: null),
        'a dot-quad with a short group is rejected': (input: '000.5e00.5300', canonical: null),
        'an empty string is rejected': (input: '', canonical: null),
      },
      outline: (example) {
        check(MacAddress.tryParse(example.input)?.value).equals(example.canonical);
      },
    );

    // An unrecognised notation and a recognised one of the wrong width are separate remedies, so
    // they must not collapse into one failure.
    scenarioOutline<({String input, MacAddressFailure failure})>(
      'MacAddress.parse attributes the failure',
      examples: {
        'unrecognisable text': (input: 'not-a-mac', failure: const MacAddressMalformed()),
        'mixed separators are a notation failure, not a width one': (
          input: '00-00:5e-00:53-00',
          failure: const MacAddressMalformed(),
        ),
        'five octets reports the count it found': (
          input: '00:00:5e:00:53',
          failure: const MacAddressWrongOctetCount(5),
        ),
        'seven octets reports the count it found': (
          input: '00:00:5e:00:53:00:12',
          failure: const MacAddressWrongOctetCount(7),
        ),
        'a lone octet counts as one': (input: '00', failure: const MacAddressWrongOctetCount(1)),
      },
      outline: (example) {
        check(MacAddress.parse(example.input).reasonOrNull).equals(example.failure);
      },
    );

    // The second hex digit of the first octet fixes both bits, so sixteen rows pin the whole
    // classification, including that the SLAP bits above them are ignored.
    scenarioOutline<({String input, bool multicast, bool local})>(
      'MacAddress reads the I/G and U/L bits off the first octet',
      examples: {
        'digit 0 is universal unicast': (
          input: '00:00:5e:00:53:00',
          multicast: false,
          local: false,
        ),
        'digit 1 is universal multicast': (
          input: '01:00:5e:00:53:00',
          multicast: true,
          local: false,
        ),
        'digit 2 is local unicast': (input: '02:00:5e:00:53:00', multicast: false, local: true),
        'digit 3 is local multicast': (input: '03:00:5e:00:53:00', multicast: true, local: true),
        'digit 4 is universal unicast': (
          input: '04:00:5e:00:53:00',
          multicast: false,
          local: false,
        ),
        'digit 5 is universal multicast': (
          input: '05:00:5e:00:53:00',
          multicast: true,
          local: false,
        ),
        'digit 6 is local unicast': (input: '06:00:5e:00:53:00', multicast: false, local: true),
        'digit 7 is local multicast': (input: '07:00:5e:00:53:00', multicast: true, local: true),
        'digit 8 is universal unicast': (
          input: '08:00:5e:00:53:00',
          multicast: false,
          local: false,
        ),
        'digit 9 is universal multicast': (
          input: '09:00:5e:00:53:00',
          multicast: true,
          local: false,
        ),
        'digit a is local unicast': (input: '0a:00:5e:00:53:00', multicast: false, local: true),
        'digit b is local multicast': (input: '0b:00:5e:00:53:00', multicast: true, local: true),
        'digit c is universal unicast': (
          input: '0c:00:5e:00:53:00',
          multicast: false,
          local: false,
        ),
        'digit d is universal multicast': (
          input: '0d:00:5e:00:53:00',
          multicast: true,
          local: false,
        ),
        'digit e is local unicast': (input: '0e:00:5e:00:53:00', multicast: false, local: true),
        'digit f is local multicast': (input: '0f:00:5e:00:53:00', multicast: true, local: true),
      },
      outline: (example) {
        final macAddress = MacAddress.tryParse(example.input)!;

        check(macAddress.isMulticast).equals(example.multicast);
        check(macAddress.isLocallyAdministered).equals(example.local);
      },
    );

    scenario('the addresses every network carries classify as their standards describe', () {
      // ISO 9542, RFC 2464 and IEEE 802.1D respectively. Only the IPv6 one reads as locally
      // administered: no IEEE assignment backs `33:33`, where the other two sit under real OUIs.
      final isoEndSystem = MacAddress.tryParse('09:00:2b:00:00:04')!;
      final ipv6Multicast = MacAddress.tryParse('33:33:00:00:00:01')!;
      final spanningTree = MacAddress.tryParse('01:80:c2:00:00:00')!;

      check(isoEndSystem.isMulticast).isTrue();
      check(isoEndSystem.isLocallyAdministered).isFalse();
      check(ipv6Multicast.isMulticast).isTrue();
      check(ipv6Multicast.isLocallyAdministered).isTrue();
      check(spanningTree.isMulticast).isTrue();
      check(spanningTree.isLocallyAdministered).isFalse();
    });

    scenario('only the 48-bit all-ones address is the broadcast address', () {
      check(MacAddress.tryParse('ff:ff:ff:ff:ff:ff')!.isBroadcast).isTrue();
      // Nominally local multicast, like the broadcast address, but a different destination.
      check(MacAddress.tryParse('33:33:00:00:00:01')!.isBroadcast).isFalse();
      check(MacAddress.tryParse('ff:ff:ff:ff:ff:ff:ff:ff')!.isBroadcast).isFalse();
      check(MacAddress.tryParse('00:00:5e:00:53:00')!.isBroadcast).isFalse();
    });

    scenario('equal addresses are equal, whichever notation they are built from', () {
      final canonical = MacAddress.tryParse('ac:de:48:23:45:67')!;

      check(MacAddress.tryParse('AC-DE-48-23-45-67')!).equals(canonical);
      check(MacAddress.tryParse('acde.4823.4567')!).equals(canonical);
      check(MacAddress.tryParse('ACDE48234567')!).equals(canonical);
    });

    scenario(
      'a 48- and a 64-bit address are never equal, since neither is mapped to the other',
      () {
        final fortyEightBit = MacAddress.tryParse('00:00:5e:00:53:00')!;
        final sixtyFourBit = MacAddress.tryParse('00:00:5e:10:00:00:00:00')!;

        check(fortyEightBit == sixtyFourBit).isFalse();
        check(fortyEightBit.octetCount).equals(6);
        check(sixtyFourBit.octetCount).equals(8);
      },
    );

    scenario('octets and fromOctets round-trip', () {
      final macAddress = MacAddress.tryParse('ac:de:48:23:45:67')!;

      check(macAddress.octets).deepEquals([0xac, 0xde, 0x48, 0x23, 0x45, 0x67]);
      check(MacAddress.fromOctets(macAddress.octets)).equals(macAddress);
    });

    scenario('fromOctets throws MintedFormatException unless there are six or eight octets', () {
      check(() => MacAddress.fromOctets(Uint8List(5))).throws<MintedFormatException>();
      check(() => MacAddress.fromOctets(Uint8List(7))).throws<MintedFormatException>();
      check(MacAddress.fromOctets(Uint8List(6))).equals(MacAddress.tryParse('00:00:00:00:00:00')!);
      check(MacAddress.fromOctets(Uint8List(8)).octetCount).equals(8);
    });

    scenario('the octet-count failure reports what it was handed', () {
      check(() => MacAddress.fromOctets(Uint8List(7)))
          .throws<MintedFormatException>()
          .has((error) => error.message, 'message')
          .equals('Invalid MacAddress: expected 6 or 8 octets, got 7');
    });

    scenario('prefix24 is the first three octets, and claims nothing beyond that', () {
      check(MacAddress.tryParse('AC-DE-48-23-45-67')!.prefix24).equals('ac:de:48');
      // A 64-bit address has the same 24-bit prefix: the field is a width, not a length fraction.
      check(MacAddress.tryParse('00:00:5e:10:00:00:00:00')!.prefix24).equals('00:00:5e');
    });

    scenario('ieee802 and bareHex render the other two accepted forms', () {
      final macAddress = MacAddress.tryParse('acde.4823.4567')!;

      check(macAddress.value).equals('ac:de:48:23:45:67');
      check(macAddress.ieee802).equals('AC-DE-48-23-45-67');
      check(macAddress.bareHex).equals('acde48234567');
      check(MacAddress.tryParse('00:00:5e:10:00:00:00:00')!.bareHex).equals('00005e1000000000');
    });

    scenario('compareTo orders lexicographically by canonical form', () {
      final earlier = MacAddress.tryParse('00:00:5e:00:53:00')!;
      final later = MacAddress.tryParse('00:00:5e:00:53:01')!;

      check(earlier.compareTo(later)).isLessThan(0);
      check(later.compareTo(earlier)).isGreaterThan(0);
      // Comparator test
      // ignore: avoid-passing-self-as-argument
      check(earlier.compareTo(earlier)).equals(0);
    });

    scenario('parse reports the failure rather than throwing', () {
      check(MacAddress.parse('not-a-mac')).equals(const ParseFailure(MacAddressMalformed()));
      check(MacAddress.parse('00:00:5e:00:53:00').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(MacAddress.tryParse('not-a-mac')).isNull();
      check(MacAddress.tryParse('00:00:5e:00:53:00')?.value).equals('00:00:5e:00:53:00');
    });

    scenario('the failure names the type, not its erased representation', () {
      // Extension types erase to String at runtime, so a `<T>`-derived name would read "String".
      check(MacAddress.parse('nope').reasonOrNull?.typeName).equals('MacAddress');
      check(() => MacAddress.fromOctets(Uint8List(5)))
          .throws<MintedFormatException>()
          .has((error) => error.message, 'message')
          .startsWith('Invalid MacAddress:');
    });
  });
}
