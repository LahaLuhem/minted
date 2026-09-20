/// @docImport 'natural_number.dart';
library;

part '../constants/uint_constants.dart';

/// An integer that is never negative: `0` or more.
///
/// Where zero is not a legal answer, reach for [NaturalNumber]. They differ by that one value.
///
/// > [!IMPORTANT]
/// > Despite the borrowed name this constrains the sign, not a machine width: nothing wraps,
/// > and there is no upper bound.
///
/// Named values: [UintConstants].
///
/// {@example /example/minted_constraints_example.dart#quantities}
extension type const Uint._(int value) implements int {
  /// The [Uint] with numeric [value], or `null` if it's negative.
  static Uint? tryFrom(int value) => value < UintConstants.zero ? null : ._(value);
}
