part of '../iban.dart';

/// The [Iban] worked example everyone uses. Its `WEST` names no real bank.
abstract final class IbanConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// `GB82 WEST 1234 5698 7654 32`, the usual worked example. Its `WEST` names no real bank.
  static const example = Iban._('GB82WEST12345698765432');
}
