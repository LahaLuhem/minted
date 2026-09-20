/// @docImport '../payment_card_number.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [PaymentCardNumber] refused its input. Sealed rather than an enum, because [PaymentCardNumberWrongLength]
/// carries a value off the input.
@immutable
sealed class const PaymentCardNumberFailure() implements MintedFailure {
  /// Subclasses only: the type is sealed.
  this;

  @override
  String get typeName => 'PaymentCardNumber';
}

/// Outside the 8-to-19-digit window ISO/IEC 7812 allows a primary account number.
final class const PaymentCardNumberWrongLength(
  /// How many characters were left after separators came off.
  final int actualLength,
) extends PaymentCardNumberFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'expected 8 to 19 digits, got $actualLength';

  @override
  bool operator ==(Object other) =>
      other is PaymentCardNumberWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(PaymentCardNumberWrongLength, actualLength);

  @override
  String toString() => 'PaymentCardNumberWrongLength($actualLength)';
}

/// Something outside `0`-`9` got through. Spaces and hyphens come off first.
final class const PaymentCardNumberInvalidCharacters() extends PaymentCardNumberFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'contains characters outside 0-9';

  @override
  bool operator ==(Object other) => other is PaymentCardNumberInvalidCharacters;

  @override
  int get hashCode => (PaymentCardNumberInvalidCharacters).hashCode;

  @override
  String toString() => 'PaymentCardNumberInvalidCharacters()';
}

/// The last digit doesn't match the rest. A digit is mistyped or swapped.
final class const PaymentCardNumberChecksumFailed() extends PaymentCardNumberFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'failed the Luhn check';

  @override
  bool operator ==(Object other) => other is PaymentCardNumberChecksumFailed;

  @override
  int get hashCode => (PaymentCardNumberChecksumFailed).hashCode;

  @override
  String toString() => 'PaymentCardNumberChecksumFailed()';
}
