import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Uuid', () {
    // A well-formed UUID round-trips through value (lower-cased, wrappers stripped); null means
    // rejected. The canonical form doubles as the expected outcome.
    scenarioOutline<({String input, String? canonical})>(
      'Uuid.tryParse accepts well-formed UUIDs, normalises them, and rejects the rest',
      examples: {
        'a canonical lowercase UUID': (
          input: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
          canonical: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
        ),
        'uppercase is lower-cased': (
          input: 'F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6',
          canonical: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
        ),
        'mixed case is lower-cased': (
          input: 'F81d4FAE-7dec-11D0-a765-00A0c91E6bf6',
          canonical: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
        ),
        'a urn:uuid: prefix is stripped': (
          input: 'urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
          canonical: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
        ),
        'an uppercase URN prefix is stripped': (
          input: 'URN:UUID:F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6',
          canonical: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
        ),
        'surrounding braces are stripped': (
          input: '{f81d4fae-7dec-11d0-a765-00a0c91e6bf6}',
          canonical: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
        ),
        'surrounding whitespace is trimmed': (
          input: '  f81d4fae-7dec-11d0-a765-00a0c91e6bf6  ',
          canonical: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
        ),
        'the Nil UUID': (
          input: '00000000-0000-0000-0000-000000000000',
          canonical: '00000000-0000-0000-0000-000000000000',
        ),
        'the Max UUID is lower-cased': (
          input: 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF',
          canonical: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
        ),
        'bare 32-hex without hyphens is rejected': (
          input: 'f81d4fae7dec11d0a76500a0c91e6bf6',
          canonical: null,
        ),
        'a non-hex digit is rejected': (
          input: 'g81d4fae-7dec-11d0-a765-00a0c91e6bf6',
          canonical: null,
        ),
        'too short is rejected': (input: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf', canonical: null),
        'too long is rejected': (input: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6a', canonical: null),
        'hyphens in the wrong place is rejected': (
          input: 'f81d4fae-7de-c11d0-a765-00a0c91e6bf6',
          canonical: null,
        ),
        'internal whitespace is rejected': (
          input: 'f81d4fae-7dec-11d0-a765-00a0c9 1e6bf6',
          canonical: null,
        ),
        'an empty string is rejected': (input: '', canonical: null),
        'a bare urn prefix is rejected': (input: 'urn:uuid:', canonical: null),
        'empty braces are rejected': (input: '{}', canonical: null),
      },
      outline: (example) {
        check(Uuid.tryParse(example.input)?.value).equals(example.canonical);
      },
    );

    // Version is the 4-bit field at the first hex digit of the third group. Vectors are the
    // RFC 9562 Appendix A examples, one per version, plus the two sentinels.
    scenarioOutline<({String input, int version})>(
      'Uuid.version reads the version field',
      examples: {
        'v1 (RFC 9562 A.1)': (input: 'C232AB00-9414-11EC-B3C8-9F6BDECED846', version: 1),
        'v3 (A.2)': (input: '5DF41881-3AED-3515-88A7-2F4A814CF09E', version: 3),
        'v4 (A.3)': (input: '919108F7-52D1-4320-9BAC-F847DB4148A8', version: 4),
        'v5 (A.4)': (input: '2ED6657D-E927-568B-95E1-2665A8AEA6A2', version: 5),
        'v6 (A.5)': (input: '1EC9414C-232A-6B00-B3C8-9F6BDECED846', version: 6),
        'v7 (A.6)': (input: '017F22E2-79B0-7CC3-98C4-DC0C0C07398F', version: 7),
        'v8 (A.7)': (input: '2489E9AD-2EE2-8E00-8EC9-32D5F69181C0', version: 8),
        'the Nil UUID is version 0': (input: '00000000-0000-0000-0000-000000000000', version: 0),
        'the Max UUID is version 15': (input: 'ffffffff-ffff-ffff-ffff-ffffffffffff', version: 15),
      },
      outline: (example) {
        check(Uuid.parse(example.input).version).equals(example.version);
      },
    );

    // Variant is classified from the first hex digit of the fourth group, including the bucket
    // boundaries (7/8, b/c, d/e).
    scenarioOutline<({String input, UuidVariant variant})>(
      'Uuid.variant classifies the variant field',
      examples: {
        'an RFC 9562 UUID (nibble 9)': (
          input: '919108f7-52d1-4320-9bac-f847db4148a8',
          variant: UuidVariant.rfc9562,
        ),
        'nibble 8 is RFC 9562': (
          input: '00000000-0000-0000-8000-000000000000',
          variant: UuidVariant.rfc9562,
        ),
        'nibble b is RFC 9562': (
          input: '00000000-0000-0000-b000-000000000000',
          variant: UuidVariant.rfc9562,
        ),
        'the Nil UUID is NCS': (
          input: '00000000-0000-0000-0000-000000000000',
          variant: UuidVariant.ncs,
        ),
        'nibble 7 is NCS': (
          input: '00000000-0000-0000-7000-000000000000',
          variant: UuidVariant.ncs,
        ),
        'nibble c is Microsoft': (
          input: '00000000-0000-0000-c000-000000000000',
          variant: UuidVariant.microsoft,
        ),
        'nibble d is Microsoft': (
          input: '00000000-0000-0000-d000-000000000000',
          variant: UuidVariant.microsoft,
        ),
        'nibble e is future': (
          input: '00000000-0000-0000-e000-000000000000',
          variant: UuidVariant.future,
        ),
        'the Max UUID is the future variant': (
          input: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
          variant: UuidVariant.future,
        ),
      },
      outline: (example) {
        check(Uuid.parse(example.input).variant).equals(example.variant);
      },
    );

    scenario('the Nil and Max sentinels are recognised', () {
      final nil = Uuid.parse('00000000-0000-0000-0000-000000000000');
      final max = Uuid.parse('ffffffff-ffff-ffff-ffff-ffffffffffff');
      final ordinary = Uuid.parse('f81d4fae-7dec-11d0-a765-00a0c91e6bf6');

      check(nil.isNil).isTrue();
      check(nil.isMax).isFalse();
      check(max.isMax).isTrue();
      check(max.isNil).isFalse();
      check(ordinary.isNil).isFalse();
      check(ordinary.isMax).isFalse();
    });

    scenario('equal UUIDs are equal, whichever spelling they are built from', () {
      final canonical = Uuid.parse('f81d4fae-7dec-11d0-a765-00a0c91e6bf6');

      check(Uuid.parse('F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6')).equals(canonical);
      check(Uuid.parse('urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6')).equals(canonical);
      check(Uuid.parse('{f81d4fae-7dec-11d0-a765-00a0c91e6bf6}')).equals(canonical);
    });

    scenario('urn rebuilds the URN form from the canonical value', () {
      check(
        Uuid.parse('F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6').urn,
      ).equals('urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6');
    });

    scenario('bytes and fromBytes round-trip', () {
      final uuid = Uuid.parse('f81d4fae-7dec-11d0-a765-00a0c91e6bf6');

      check(uuid.bytes).deepEquals([
        0xf8, 0x1d, 0x4f, 0xae, 0x7d, 0xec, 0x11, 0xd0, //
        0xa7, 0x65, 0x00, 0xa0, 0xc9, 0x1e, 0x6b, 0xf6,
      ]);
      check(Uuid.fromBytes(uuid.bytes)).equals(uuid);
    });

    scenario('fromBytes throws MintedFormatException unless there are exactly 16 bytes', () {
      check(() => Uuid.fromBytes(Uint8List(15))).throws<MintedFormatException>();
      check(() => Uuid.fromBytes(Uint8List(17))).throws<MintedFormatException>();
      check(
        Uuid.fromBytes(Uint8List(16)),
      ).equals(Uuid.parse('00000000-0000-0000-0000-000000000000'));
    });

    scenario('compareTo orders lexicographically by canonical form', () {
      final earlier = Uuid.parse('00000000-0000-0000-0000-000000000001');
      final later = Uuid.parse('00000000-0000-0000-0000-000000000002');

      check(earlier.compareTo(later)).isLessThan(0);
      check(later.compareTo(earlier)).isGreaterThan(0);
      // Comparator test
      // ignore: avoid-passing-self-as-argument
      check(earlier.compareTo(earlier)).equals(0);
    });

    scenario('Uuid.parse throws MintedFormatException, carrying the source', () {
      check(() => Uuid.parse('not-a-uuid'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('not-a-uuid');
    });

    scenario('the exception message names the type, not its erased representation', () {
      // Extension types erase to String at runtime, so a `<T>`-derived message would read
      // "Invalid String"; the message must name Uuid.
      check(() => Uuid.parse('nope'))
          .throws<MintedFormatException>()
          .has((error) => error.message, 'message')
          .startsWith('Invalid Uuid:');
    });
  });
}
