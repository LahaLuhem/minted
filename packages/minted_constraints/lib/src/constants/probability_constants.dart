// A Probability erases to its double, so the lint offers the raw bound in its place.
// ignore_for_file: use_named_constants

part of '../quantities/probability.dart';

/// The [Probability] bounds, and the even chance between them.
abstract final class ProbabilityConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The event cannot happen: exactly `0`.
  static const impossible = Probability._(Probability._impossible);

  /// An even chance, the coin toss: exactly `0.5`.
  static const evenChance = Probability._(0.5);

  /// The event must happen: exactly `1`.
  static const certain = Probability._(Probability._certain);
}
