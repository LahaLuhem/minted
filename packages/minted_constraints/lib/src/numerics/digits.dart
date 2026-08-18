import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'package:minted/internal.dart';

import 'digit.dart';

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

  const new _(this._bytes);

  /// The sequence of the given [values], or `null` unless every value is in `0`-`9`.
  // Asks [Digit] what a digit is rather than re-deciding: one range, one place.
  static Digits? tryFrom(List<int> values) => values.any((value) => Digit.tryFrom(value) == null)
      ? null
      : ._(.fromList(values.toList(growable: false)));

  /// The sequence built from the given `digits`, minted directly: each is already `0`-`9`.
  static Digits of(Iterable<Digit> digits) =>
      ._(.fromList([for (final digit in digits) digit.value]));

  // Each byte came from a Digit, so tryFrom cannot return null here.
  @override
  Iterator<Digit> get iterator => _bytes.map((byte) => Digit.tryFrom(byte)!).iterator;

  @override
  int get length => _bytes.length;

  /// The [Digit] at [index] (0-based).
  Digit operator [](int index) => Digit.tryFrom(_bytes[index])!;

  /// The digits as a plain string, e.g. `'12345'` (the canonical form).
  String get asString => .fromCharCodes(_bytes.map(decimalCodeUnit));

  @override
  bool operator ==(Object other) => other is Digits && _byteEquality.equals(_bytes, other._bytes);

  @override
  int get hashCode => _byteEquality.hash(_bytes);

  @override
  String toString() => 'Digits($asString)';

  static const _byteEquality = ListEquality<int>();
}
