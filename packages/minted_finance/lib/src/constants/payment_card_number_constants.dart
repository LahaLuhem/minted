part of '../payment_card_number.dart';

/// The test PANs processors publish, 1 per scheme. No standard reserves them.
abstract final class PaymentCardNumberConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// Visa.
  static const testVisa = PaymentCardNumber._('4242424242424242');

  /// Mastercard.
  static const testMastercard = PaymentCardNumber._('5555555555554444');

  /// American Express, 15 digits rather than 16.
  static const testAmericanExpress = PaymentCardNumber._('378282246310005');

  /// Discover.
  static const testDiscover = PaymentCardNumber._('6011111111111117');

  /// Diners Club, 14 digits.
  static const testDinersClub = PaymentCardNumber._('3056930009020004');

  /// JCB.
  static const testJcb = PaymentCardNumber._('3566002020360505');

  /// UnionPay.
  static const testUnionPay = PaymentCardNumber._('6200000000000005');
}
