// A validated UUID is ASCII hex and hyphens only, so substring slicing is byte-safe.
// ignore_for_file: avoid-substring

import 'dart:typed_data';

import '../shared/minted_format_exception.dart';

/// A UUID (Universally Unique IDentifier): 128 bits in the canonical `8-4-4-4-12` hex form, e.g.
/// `f81d4fae-7dec-11d0-a765-00a0c91e6bf6`.
/// Standard: [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562), which obsoletes RFC 4122.
///
/// Parse, don't validate: a [Uuid] exists only if it is a well-formed UUID string. The `uuid`
/// package *generates* UUIDs and hands back a plain `String`; [Uuid] is the value type that
/// *types* an existing one, so "this is a real UUID" becomes a fact of the type instead of a
/// `String` every caller re-checks.
///
/// A UUID carries no checksum, so every structurally well-formed UUID is accepted, including the
/// [isNil] and [isMax] sentinels and every possible [version] and [variant]. The version and
/// variant are read back through accessors, never used to reject input: refusing them would reject
/// values RFC 9562 itself defines as valid.
///
/// Normalisation on parse: surrounding whitespace is trimmed, the hex is lower-cased, and an
/// optional `urn:uuid:` prefix or surrounding `{…}` is stripped, so [value] is always the bare
/// lowercase canonical form. Because extension-type equality is representation equality, mixed-case,
/// URN, and brace-wrapped spellings of the same UUID all compare equal. [urn] rebuilds the URN form.
extension type const Uuid._(String value) {
  /// Parses [input] as a UUID, or returns `null` unless it is the canonical `8-4-4-4-12` hex form
  /// (case-insensitive), optionally wrapped as `urn:uuid:…` or `{…}`.
  static Uuid? tryParse(String input) {
    final unwrapped = _unwrap(input.trim().toLowerCase());
    if (!_canonical.hasMatch(unwrapped)) return null;

    return ._(unwrapped);
  }

  /// Parses [input] as a UUID, throwing [MintedFormatException] unless it is a well-formed UUID
  /// string (canonical, `urn:uuid:`-prefixed, or brace-wrapped).
  static Uuid parse(String input) =>
      tryParse(input) ??
      (throw MintedFormatException.of(
        'Uuid',
        input,
        'not a well-formed UUID (expected 8-4-4-4-12 hex)',
      ));

  /// Builds a [Uuid] from its 16 [bytes] (big-endian, the standard byte order), throwing
  /// [MintedFormatException] unless there are exactly 16. Every 16-byte sequence is a valid UUID,
  /// so this only rejects the wrong length. The inverse of [bytes].
  static Uuid fromBytes(Uint8List bytes) {
    if (bytes.length != _byteCount) {
      throw MintedFormatException.of(
        'Uuid',
        '$bytes',
        'expected $_byteCount bytes, got ${bytes.length}',
      );
    }

    final hex = bytes
        .map((byte) => byte.toRadixString(_hexRadix).padLeft(_byteHexLength, _padChar))
        .join();

    return parse(_hyphenate(hex));
  }

  /// The UUID version, `0`-`15`: the 4-bit version field (the first hex digit of the third group).
  ///
  /// RFC 9562 defines `1` (Gregorian time), `2` (DCE security), `3` (name-based, MD5), `4` (random),
  /// `5` (name-based, SHA-1), `6` (reordered time), `7` (Unix-epoch time), and `8` (custom); `0` and
  /// `9`-`15` are unused or reserved. Left as an `int` rather than an enum because it is a raw 4-bit
  /// field with reserved ranges an enum could not name honestly.
  int get version => int.parse(value[_versionIndex], radix: _hexRadix);

  /// The [UuidVariant] this UUID belongs to: the layout family named by the variant bits (the first
  /// hex digit of the fourth group).
  UuidVariant get variant {
    final nibble = int.parse(value[_variantIndex], radix: _hexRadix);

    return switch (nibble) {
      < _rfc9562VariantFloor => .ncs,
      < _microsoftVariantFloor => .rfc9562,
      < _futureVariantFloor => .microsoft,
      _ => .future,
    };
  }

  /// Whether this is the Nil UUID, `00000000-0000-0000-0000-000000000000`: the all-zero sentinel
  /// RFC 9562 uses to mean "no UUID here".
  bool get isNil => value == _nil;

  /// Whether this is the Max UUID, `ffffffff-ffff-ffff-ffff-ffffffffffff`: the all-ones sentinel
  /// RFC 9562 uses as an upper bound (e.g. "end of a UUID range").
  bool get isMax => value == _max;

  /// The URN form, `urn:uuid:<value>`, for use where a UUID is written as a Uniform Resource Name.
  String get urn => '$_urnPrefix$value';

  /// The 16 raw bytes (big-endian), the inverse of [fromBytes]. Handy for binary interop (a database
  /// `uuid` column, a byte protocol) where the hex string would waste space.
  Uint8List get bytes {
    final hex = value.replaceAll(_hyphen, '');

    return Uint8List.fromList([
      for (var offset = 0; offset < hex.length; offset += _byteHexLength)
        int.parse(hex.substring(offset, offset + _byteHexLength), radix: _hexRadix),
    ]);
  }

  /// Orders two UUIDs lexicographically by their canonical form. For [version] `7`, whose leading
  /// bits are a timestamp, this is also creation-time order. Extension types cannot implement
  /// `Comparable<Uuid>`, so this is a plain method rather than the [Comparable] interface.
  int compareTo(Uuid other) => value.compareTo(other.value);

  // Strips an optional `urn:uuid:` prefix or a surrounding `{…}` from the already-lowercased input.
  static String _unwrap(String lowerInput) {
    if (lowerInput.startsWith(_urnPrefix)) {
      return lowerInput.substring(_urnPrefix.length);
    }
    if (lowerInput.startsWith(_braceOpen) && lowerInput.endsWith(_braceClose)) {
      return lowerInput.substring(_braceOpen.length, lowerInput.length - _braceClose.length);
    }

    return lowerInput;
  }

  // Groups 32 hex digits into the canonical 8-4-4-4-12 hyphenated form, slicing at each boundary.
  static String _hyphenate(String hex) => Iterable.generate(
    _groupHexBoundaries.length - 1,
    (group) => hex.substring(_groupHexBoundaries[group], _groupHexBoundaries[group + 1]),
  ).join(_hyphen);

  static final _canonical = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static const _versionIndex = 14;
  static const _variantIndex = 19;
  static const _hexRadix = 16;
  static const _byteCount = 16;
  static const _byteHexLength = 2;
  // Cut points bracketing the 8-4-4-4-12 hex groups (one more than the group count).
  static const _groupHexBoundaries = [0, 8, 12, 16, 20, 32];
  static const _padChar = '0';
  static const _hyphen = '-';
  static const _urnPrefix = 'urn:uuid:';
  static const _braceOpen = '{';
  static const _braceClose = '}';
  static const _nil = '00000000-0000-0000-0000-000000000000';
  static const _max = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  static const _rfc9562VariantFloor = 0x8;
  static const _microsoftVariantFloor = 0xc;
  static const _futureVariantFloor = 0xe;
}

/// The variant of a [Uuid]: which layout family it belongs to, named by the variant bits (the first
/// hex digit of the fourth group). See [RFC 9562 §4.1](https://www.rfc-editor.org/rfc/rfc9562#section-4.1).
enum UuidVariant {
  /// Reserved for NCS (Network Computing System) backward compatibility; variant bits `0xxx`. The
  /// [Uuid.isNil] sentinel falls here.
  ncs,

  /// The layout defined by RFC 9562 (and RFC 4122 before it); variant bits `10xx`. The variant of
  /// essentially every UUID in practice.
  rfc9562,

  /// Reserved for Microsoft backward compatibility; variant bits `110x`.
  microsoft,

  /// Reserved for future definition; variant bits `111x`. The [Uuid.isMax] sentinel falls here.
  future,
}
