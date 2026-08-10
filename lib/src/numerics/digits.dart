import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../shared/minted_format_exception.dart';
import '../shared/parse_outcome.dart';
import 'digit.dart';
import 'failures/digits_failure.dart';

/// An immutable, iterable sequence of decimal digits, each a [Digit] (`0`-`9`).
///
/// A digits-only identifier (a bank account number, a national phone number, a
/// SKU) modelled as digits rather than a raw `String`, so letters and other junk
/// are unrepresentable. It is validated once on construction; after that you
/// iterate it, index it, or read [asString], without re-checking.
///
/// Backed by a `Uint8List` (one byte per digit, a real `Uint8Array` on the web),
/// kept private so a denser packing can replace it behind this same interface.
/// Equality is by value over the digits.
@immutable
final class Digits extends Iterable<Digit> {
  final Uint8List _bytes;

  const Digits._(this._bytes);

  /// Parses [input] as a run of decimal digits, or returns `null` when any
  /// character is not `0`-`9`. Empty input yields an empty sequence.
  static Digits? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a run of decimal digits, reporting [DigitsFailure] when
  /// any character is not `0`-`9`. Empty input yields an empty sequence.
  static ParseOutcome<DigitsFailure, Digits> parse(String input) {
    final codeUnits = input.codeUnits;
    final parsedDigits = !codeUnits.every(_isAsciiDigit)
        ? null
        : Digits._(Uint8List.fromList([for (final code in codeUnits) code - _asciiZero]));

    return parsedDigits == null
        ? const ParseFailure(DigitsFailure.notAllDigits)
        : ParseSuccess(parsedDigits);
  }

  /// The sequence of the given [values], or `null` unless every value is in `0`-`9`.
  static Digits? tryFrom(List<int> values) =>
      !values.every(_isDigitValue) ? null : ._(.fromList(values.toList(growable: false)));

  /// The sequence of the given [values], throwing [MintedFormatException] unless
  /// every value is in `0`-`9`.
  static Digits from(Iterable<int> values) =>
      tryFrom(values.toList(growable: false)) ??
      (throw MintedFormatException.from(DigitsFailure.notAllDigits, '$values'));

  /// The sequence built from the given `digits` (each already a valid `0`-`9`).
  static Digits of(Iterable<Digit> digits) => from(digits.map((digit) => digit.value));

  @override
  Iterator<Digit> get iterator => _bytes.map(Digit.from).iterator;

  @override
  int get length => _bytes.length;

  /// The [Digit] at [index] (0-based).
  Digit operator [](int index) => Digit.from(_bytes[index]);

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
