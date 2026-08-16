// Hex is ASCII, so substring slicing is byte-safe.
// ignore_for_file: avoid-substring

/// Hex text to bytes and back, in one place so a type whose canonical form is hex does not carry its
/// own copy of the pairing loop in each direction.
///
/// Public within `lib/src/` and never re-exported from `lib/minted.dart`: top-level `_` names are
/// library-private in Dart, so sharing them at all means dropping the underscore.
library;

import 'dart:typed_data';

import '../normalisation/normalisation.dart';

/// The radix hex is written in.
const hexRadix = 16;

/// How many hex digits spell one byte.
const hexDigitsPerByte = 2;

/// The bytes [hex] spells, two digits per byte.
///
/// Assumes an even number of hex digits, which is what a validated hex value holds; an odd count is
/// a caller bug and throws where the last pair runs off the end.
Uint8List hexBytes(String hex) => .fromList([
  for (var offset = 0; offset < hex.length; offset += hexDigitsPerByte)
    int.parse(hex.substring(offset, offset + hexDigitsPerByte), radix: hexRadix),
]);

/// [bytes] as lowercase hex, two digits each: the inverse of [hexBytes].
String hexDigits(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(hexRadix).padLeft(hexDigitsPerByte, zeroPad)).join();
