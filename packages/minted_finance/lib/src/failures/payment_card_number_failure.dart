/// @docImport '../payment_card_number.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [PaymentCardNumber] refused its input. Sealed, not an enum, because
/// [PaymentCardNumberWrongLength] reports a value read from the input.
///
/// Three variants: ISO/IEC 7812 is a length window, a charset, and the Luhn check, and the card
/// scheme is reported rather than validated, so there is nothing else to fail against.
@immutable
sealed class PaymentCardNumberFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'PaymentCardNumber';
}

/// Outside the 8-to-19-digit window ISO/IEC 7812 allows a primary account number.
final class PaymentCardNumberWrongLength extends PaymentCardNumberFailure {
  /// How many characters were left once separators were stripped.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

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

/// Something outside `0`-`9` survived normalisation (spaces and hyphens are stripped first).
final class PaymentCardNumberInvalidCharacters extends PaymentCardNumberFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'contains characters outside 0-9';

  @override
  bool operator ==(Object other) => other is PaymentCardNumberInvalidCharacters;

  @override
  int get hashCode => (PaymentCardNumberInvalidCharacters).hashCode;

  @override
  String toString() => 'PaymentCardNumberInvalidCharacters()';
}

/// The final digit disagrees with the rest of the number: a digit is mistyped or transposed.
final class PaymentCardNumberChecksumFailed extends PaymentCardNumberFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'failed the Luhn check';

  @override
  bool operator ==(Object other) => other is PaymentCardNumberChecksumFailed;

  @override
  int get hashCode => (PaymentCardNumberChecksumFailed).hashCode;

  @override
  String toString() => 'PaymentCardNumberChecksumFailed()';
}
