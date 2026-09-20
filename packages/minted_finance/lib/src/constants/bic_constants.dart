part of '../bic.dart';

/// The [Bic] codes documentation uses. ISO 9362 reserves none, so both are habit.
abstract final class BicConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// A German example code.
  static const exampleDe = Bic._('BANKDEFFXXX');

  /// A Belgian one, for an example needing both ends of a payment.
  static const exampleBe = Bic._('BANKBEBBXXX');
}
