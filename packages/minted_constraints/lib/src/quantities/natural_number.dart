/// @docImport 'uint.dart';
library;

/// An integer strictly greater than zero: `1` or more.
///
/// Where zero is a legal answer, reach for [Uint]. There is no upper bound.
///
/// > [!NOTE]
/// > **Zero is excluded**, and that needs saying because the convention is split: ISO 80000-2
/// > counts `0` among the naturals, school arithmetic starts at `1`. This type takes the second
/// > reading.
///
/// [value] is the numeric value. The string form is `value.toString()`.
///
/// [one] is the floor. There is no ceiling.
///
/// {@example /example/minted_constraints_example.dart#quantities}
extension type const NaturalNumber._(int value) implements int {
  /// The [NaturalNumber] with numeric [value], or `null` unless it is `1` or more.
  static NaturalNumber? tryFrom(int value) => value < one ? null : ._(value);

  /// The smallest natural number: `1`.
  static const one = NaturalNumber._(1);
}
