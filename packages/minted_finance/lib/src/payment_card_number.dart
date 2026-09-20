// A validated card number is ASCII digits only.
// ignore_for_file: avoid-substring

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'failures/payment_card_number_failure.dart';

part 'helpers/payment_card_number_helpers.dart';

/// A payment card number: the ISO/IEC 7812 primary account number (PAN). Credit, debit, prepaid
/// and gift cards all share the numbering scheme.
/// Standard: [ISO/IEC 7812](https://en.wikipedia.org/wiki/Payment_card_number).
///
/// Parsing strips spaces and hyphens, so a card's grouped form and its compact form compare equal.
///
/// A class rather than an extension type so [toString] renders [masked] instead of [value]. A PAN in
/// a log line is a leak. The card scheme is reported, never validated. See [cardScheme].
///
/// {@example /example/minted_finance_example.dart#card}
@immutable
final class const PaymentCardNumber._(
  /// The primary account number, digits only. The one member that reveals the card, so reach for [masked]
  /// anywhere the result might be logged.
  final String value,
) {
  /// Builds a [PaymentCardNumber] from an [iin] and [accountIdentifier], working the Luhn check digit
  /// out.
  static ParseOutcome<PaymentCardNumberFailure, PaymentCardNumber> fromComponents({
    required Digits iin,
    required Digits accountIdentifier,
  }) {
    final assembledNumber = _withCheckDigit('${iin.asString}${accountIdentifier.asString}');
    final failure = _failureFor(assembledNumber);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(assembledNumber));
  }

  /// Parses [input], or `null` if it isn't a card number.
  static PaymentCardNumber? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [PaymentCardNumberFailure] that says what went wrong.
  static ParseOutcome<PaymentCardNumberFailure, PaymentCardNumber> parse(String input) {
    final compactInput = compact(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(compactInput));
  }

  /// Which schemes claim [input]'s prefix, with no length or Luhn requirement, so a form can show a
  /// card's brand mid-typing. An instance can't: partial input doesn't parse.
  ///
  /// Empty until enough digits arrive to place a range, and empty for a prefix no listed scheme claims.
  /// 2 entries where a range is genuinely co-branded.
  static Set<CardScheme> cardSchemesOf(String input) {
    final compactInput = compact(input);

    return Set.unmodifiable(
      _schemeRanges
          .where((candidateRange) => candidateRange.digits <= compactInput.length)
          .where((placeableRange) {
            final prefixValue = int.tryParse(compactInput.substring(0, placeableRange.digits));

            return prefixValue != null &&
                prefixValue >= placeableRange.from &&
                prefixValue <= placeableRange.to;
          })
          .map((claimingRange) => claimingRange.scheme),
    );
  }

  /// The major industry identifier: the leading digit, which ISO/IEC 7812 assigns to an industry.
  // A validated number is all digits, so neither this nor checkDigit can return null.
  Digit get majorIndustryIdentifier => .tryFrom(decimalValue(value.codeUnitAt(0)))!;

  /// The 6-digit issuer identification number, or `null` if the number is too short to hold one alongside
  /// a check digit.
  String? get iin6 => value.length > _iin6Length ? value.substring(0, _iin6Length) : null;

  /// The 8-digit issuer identification number ISO/IEC 7812:2017 widened to, or `null` as [iin6].
  String? get iin8 => value.length > _iin8Length ? value.substring(0, _iin8Length) : null;

  /// The last 4 digits: the part receipts print and systems keep.
  String get last4 => value.substring(value.length - _last4Length);

  /// The last digit, the Luhn check over the others.
  Digit get checkDigit => .tryFrom(decimalValue(value.codeUnitAt(value.length - 1)))!;

  /// Everything but [last4] hidden, `••••1111`. What [toString] renders, so a log line or a test failure
  /// can't leak the number.
  String get masked => '$_maskGlyphs$last4';

  /// The schemes claiming this number's prefix. See [cardSchemesOf].
  Set<CardScheme> get cardSchemes => cardSchemesOf(value);

  /// The single scheme claiming this number, or [CardScheme.unknown] when none does or several do. Read
  /// [cardSchemes] to tell those 2 apart.
  CardScheme get cardScheme => cardSchemes.singleOrNull ?? .unknown;

  @override
  bool operator ==(Object other) => other is PaymentCardNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PaymentCardNumber($masked)';

  // The test PANs Stripe publishes. A convention: ISO/IEC 7812 reserves no test range.

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
