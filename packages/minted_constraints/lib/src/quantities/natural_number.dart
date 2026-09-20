import 'uint.dart';

part '../constants/natural_number_constants.dart';

/// An integer strictly greater than zero: `1` or more.
///
/// Where zero is a legal answer, reach for [Uint]. There is no upper bound.
///
/// Every natural number is a [Uint], and `implements Uint` lets one go wherever a `Uint` is wanted,
/// never the reverse. `int` still comes through, by way of `Uint`.
///
/// > [!NOTE]
/// > **Zero is excluded**, and that needs saying because the convention is split: ISO 80000-2
/// > counts `0` among the naturals, school arithmetic starts at `1`. This type takes the second
/// > reading.
///
/// Named values: [NaturalNumberConstants].
///
/// {@example /example/minted_constraints_example.dart#quantities}
extension type const NaturalNumber._(int value) implements Uint {
  /// The [NaturalNumber] with numeric [value], or `null` unless it's `1` or more.
  static NaturalNumber? tryFrom(int value) => value < NaturalNumberConstants.one ? null : ._(value);
}
