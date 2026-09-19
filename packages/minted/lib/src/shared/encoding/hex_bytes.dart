// Hex is ASCII, so substring slicing is byte-safe.
// ignore_for_file: avoid-substring

/// Hex text to bytes and back, in one place so no hex-backed type carries its own pairing loop.
library;

import 'dart:typed_data';

import '../normalisation/normalisation.dart';

/// The radix hex is written in.
const hexRadix = 16;

/// How many hex digits spell one byte.
const hexDigitsPerByte = 2;

/// The bytes [hex] spells, 2 digits per byte.
///
/// Assumes an even number of digits, which is what a validated hex value holds. An odd count is a caller
/// bug, and throws where the last pair runs off the end.
Uint8List hexBytes(String hex) => .fromList([
  for (var offset = 0; offset < hex.length; offset += hexDigitsPerByte)
    int.parse(hex.substring(offset, offset + hexDigitsPerByte), radix: hexRadix),
]);

/// [bytes] as lowercase hex, 2 digits each. The inverse of [hexBytes].
String hexDigits(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(hexRadix).padLeft(hexDigitsPerByte, zeroPad)).join();
