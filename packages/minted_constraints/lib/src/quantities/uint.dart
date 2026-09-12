/// @docImport 'natural_number.dart';
library;

/// An integer that is never negative: `0` or more.
///
/// Where zero is not a legal answer, reach for [NaturalNumber]. They differ by that one value.
///
/// > [!IMPORTANT]
/// > Despite the borrowed name this constrains the sign, not a machine width: nothing wraps,
/// > and there is no upper bound.
///
/// [value] is the numeric value. The string form is `value.toString()`.
///
/// [zero] is the floor. There is no ceiling.
///
/// {@example /example/minted_constraints_example.dart#quantities}
extension type const Uint._(int value) implements int {
  /// The [Uint] with numeric [value], or `null` when it is negative.
  static Uint? tryFrom(int value) => value < zero ? null : ._(value);

  /// The lowest value: `0`.
  static const zero = Uint._(0);
}
