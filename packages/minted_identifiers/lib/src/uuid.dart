import 'dart:typed_data';

import 'package:minted/internal.dart';
import 'package:minted/minted.dart';

import 'failures/uuid_failure.dart';

part 'constants/uuid_constants.dart';
part 'helpers/uuid_helpers.dart';

/// A UUID: 128 bits as `8-4-4-4-12` hex, like `f81d4fae-7dec-11d0-a765-00a0c91e6bf6`.
/// Standard: [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562).
///
/// The `uuid` package makes them. This types one you already have. There's no checksum, so anything
/// shaped right gets in, sentinels and all.
///
/// Parsing trims spaces, lower-cases the hex, and drops a `urn:uuid:` prefix or `{…}` wrapper, so all
/// those spellings compare equal.
///
/// Named values: [UuidConstants].
///
/// {@example /example/minted_identifiers_example.dart#uuid}
extension type const Uuid._(String value) {
  /// Parses [input], or `null` if it isn't a UUID.
  static Uuid? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting [UuidMalformed] if it isn't a UUID.
  static ParseOutcome<UuidFailure, Uuid> parse(String input) {
    final unwrappedInput = _unwrap(input.trim().toLowerCase());

    return !_canonical.hasMatch(unwrappedInput)
        ? const ParseFailure(UuidMalformed())
        : ParseSuccess(._(unwrappedInput));
  }

  /// Builds a [Uuid] from its 16 [bytes], big-endian. The inverse of [bytes].
  // Goes back through parse so only one place decides what a UUID is.
  static ParseOutcome<UuidFailure, Uuid> fromBytes(Uint8List bytes) => bytes.length != _byteCount
      ? ParseFailure(UuidWrongByteCount(expected: _byteCount, actual: bytes.length))
      : parse(
          Iterable.generate(
            _groupByteBoundaries.length - 1,
            (group) => hexDigits(
              bytes.getRange(_groupByteBoundaries[group], _groupByteBoundaries[group + 1]),
            ),
          ).join(hyphen),
        );

  /// The version nibble, `0`-`15`: the 3rd group's 1st hex digit. RFC 9562 uses `1`-`8` and reserves
  /// the rest.
  // An int, not an enum, because the reserved values have no honest name.
  int get version => int.parse(value[_versionIndex], radix: hexRadix);

  /// Which [UuidVariant] the 4th group's 1st hex digit puts this in.
  UuidVariant get variant {
    final nibble = int.parse(value[_variantIndex], radix: hexRadix);

    return switch (nibble) {
      < _rfc9562VariantFloor => .ncs,
      < _microsoftVariantFloor => .rfc9562,
      < _futureVariantFloor => .microsoft,
      _ => .future,
    };
  }

  /// Whether this is [UuidConstants.nil].
  bool get isNil => value == UuidConstants.nil.value;

  /// Whether this is [UuidConstants.max].
  bool get isMax => value == UuidConstants.max.value;

  /// The `urn:uuid:<value>` form.
  String get urn => '$_urnPrefix$value';

  /// The 16 raw bytes, big-endian. The inverse of [fromBytes], and what a binary column or protocol
  /// wants instead of the hex.
  Uint8List get bytes => hexBytes(value.replaceAll(hyphen, ''));

  /// Sorts by the canonical text. For a version `7` UUID that's creation order too.
  int compareTo(Uuid other) => value.compareTo(other.value);
}

/// Which layout family a [Uuid] belongs to. See [RFC 9562 §4.1](https://www.rfc-editor.org/rfc/rfc9562#section-4.1)
/// .
enum UuidVariant() {
  /// Bits `0xxx`, kept for NCS. [UuidConstants.nil] lands here.
  ncs,

  /// Bits `10xx`. What essentially every UUID in the wild is.
  rfc9562,

  /// Bits `110x`, kept for Microsoft.
  microsoft,

  /// Bits `111x`, reserved. [UuidConstants.max] lands here.
  future,
}
