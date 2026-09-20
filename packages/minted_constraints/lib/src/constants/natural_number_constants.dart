part of '../quantities/natural_number.dart';

/// The [NaturalNumber] floor. Unbounded above, so there is no ceiling to name.
abstract final class NaturalNumberConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The smallest natural number: `1`.
  static const one = NaturalNumber._(1);
}
