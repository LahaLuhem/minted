import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../shared/minted_format_exception.dart';
import 'digit.dart';

/// An immutable sequence of decimal digits, each a [Digit] (`0`-`9`).
///
/// A digits-only identifier (a bank account number, a national phone number, a
/// SKU) modelled as digits rather than a raw `String`, so letters and other junk
/// are unrepresentable. It is validated once on construction; [digits],
/// [asString] and indexing then read it back without re-checking.
///
/// Backed by a `Uint8List` (one byte per digit, a real `Uint8Array` on the web),
/// kept private so a denser packing can replace it behind this same interface.
/// Equality is by value over the digits.
@immutable
final class Digits {
  final Uint8List _bytes;

  const Digits._(this._bytes);

  /// Parses [input] as a run of decimal digits, or returns `null` when any
  /// character is not `0`-`9`. Empty input yields an empty sequence.
  static Digits? tryParse(String input) {
    final codes = input.codeUnits;

    return codes.every(_isAsciiDigit)
        ? Digits._(.fromList([for (final code in codes) code - _asciiZero]))
        : null;
  }

  /// Parses [input] as a run of decimal digits, throwing [MintedFormatException]
  /// when any character is not `0`-`9`.
  static Digits parse(String input) =>
      tryParse(input) ??
      (throw MintedFormatException.of('Digits', input, 'not a digits-only string'));

  /// The sequence of the given [values], or `null` unless every value is in `0`-`9`.
  static Digits? tryFrom(List<int> values) =>
      values.every(_isDigitValue) ? Digits._(.fromList(values)) : null;

  /// The sequence of the given [values], throwing [MintedFormatException] unless
  /// every value is in `0`-`9`.
  static Digits from(List<int> values) =>
      tryFrom(values) ??
      (throw MintedFormatException.of('Digits', '$values', 'contains a value outside 0-9'));

  /// The sequence built from the given `digits` (each already a valid `0`-`9`).
  static Digits of(Iterable<Digit> digits) => from([for (final digit in digits) digit.value]);

  /// The [Digit] at [index] (0-based).
  Digit operator [](int index) => Digit.from(_bytes[index]);

  /// How many digits the sequence holds.
  int get length => _bytes.length;

  /// Whether the sequence holds no digits.
  bool get isEmpty => _bytes.isEmpty;

  /// First elem
  Digit get first => this[0];

  /// The digits in order, as a lazy iterable of [Digit].
  Iterable<Digit> get digits => _bytes.map(Digit.from);

  /// The digits as a plain string, e.g. `'12345'` (the canonical form).
  String get asString => .fromCharCodes(_bytes.map((byte) => byte + _asciiZero));

  @override
  bool operator ==(Object other) => other is Digits && _byteEquality.equals(_bytes, other._bytes);

  @override
  int get hashCode => _byteEquality.hash(_bytes);

  @override
  String toString() => 'Digits($asString)';

  static bool _isAsciiDigit(int code) => code >= _asciiZero && code <= _asciiNine;

  static bool _isDigitValue(int value) => value >= 0 && value < _radix;

  static const _byteEquality = ListEquality<int>();
  static const _asciiZero = 0x30;
  static const _asciiNine = 0x39;
  static const _radix = 10;
}
