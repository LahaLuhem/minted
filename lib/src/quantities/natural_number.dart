/// @docImport 'uint.dart';
library;

/// An integer strictly greater than zero: `1` or more.
///
/// Where zero is a legal answer, reach for [Uint].
///
/// **Zero is excluded**, and that needs saying because the convention is split: ISO 80000-2 counts
/// `0` among the naturals, school arithmetic starts at `1`. This type takes the second reading.
/// There is no upper bound.
///
/// [value] is the numeric value; the string form is `value.toString()`.
///
/// {@example /example/minted_example.dart#quantities}
extension type const NaturalNumber._(int value) {
  /// The [NaturalNumber] with numeric [value], or `null` unless it is `1` or more.
  static NaturalNumber? tryFrom(int value) => value <= 0 ? null : ._(value);
}
