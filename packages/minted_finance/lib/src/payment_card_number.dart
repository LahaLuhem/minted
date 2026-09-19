// A validated card number is ASCII digits only.
// ignore_for_file: avoid-substring

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'failures/payment_card_number_failure.dart';

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
final class PaymentCardNumber {
  /// The primary account number, digits only. The one member that reveals the card, so reach for [masked]
  /// anywhere the result might be logged.
  final String value;

  const new _(this.value);

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

  static String _withCheckDigit(String bodyDigits) => '$bodyDigits${luhnCheckDigit(bodyDigits)}';

  // The one gate parse and fromComponents both go through. Widest check first, so the earliest wrong
  // thing gets named.
  static PaymentCardNumberFailure? _failureFor(String compactInput) => switch (compactInput) {
    _ when compactInput.length < _minLength || compactInput.length > _maxLength =>
      PaymentCardNumberWrongLength(compactInput.length),
    _ when !digitsOnly.hasMatch(compactInput) => const PaymentCardNumberInvalidCharacters(),
    _ when !_checksumHolds(compactInput) => const PaymentCardNumberChecksumFailed(),
    _ => null,
  };

  static bool _checksumHolds(String compactInput) =>
      compactInput.endsWith(luhnCheckDigit(compactInput.substring(0, compactInput.length - 1)));

  // Only ranges no other known network contests, so a contested one reads as unknown rather than as
  // a confident wrong answer. Why the full registry stays out: APPENDIX.md#payment-card-number-value-type.
  static const _schemeRanges = <_SchemeRange>{
    (scheme: .visa, digits: 1, from: 4, to: 4),
    (scheme: .mastercard, digits: 2, from: 51, to: 55),
    (scheme: .mastercard, digits: 4, from: 2221, to: 2720),
    (scheme: .americanExpress, digits: 2, from: 34, to: 34),
    (scheme: .americanExpress, digits: 2, from: 37, to: 37),
    (scheme: .jcb, digits: 4, from: 3528, to: 3589),
    (scheme: .dinersClub, digits: 2, from: 30, to: 30),
    (scheme: .dinersClub, digits: 2, from: 36, to: 36),
    (scheme: .dinersClub, digits: 2, from: 38, to: 39),
    (scheme: .discover, digits: 4, from: 6011, to: 6011),
    (scheme: .discover, digits: 3, from: 644, to: 649),
    (scheme: .discover, digits: 6, from: 622126, to: 622925),
    (scheme: .unionPay, digits: 2, from: 62, to: 62),
  };

  static const _minLength = 8;
  static const _maxLength = 19;
  static const _iin6Length = 6;
  static const _iin8Length = 8;
  static const _last4Length = 4;
  static const _maskGlyphs = '••••';
}

// One scheme's inclusive prefix range: that many leading digits read as a number. A scheme with several
// ranges gets a row each, and the result set dedupes them.
typedef _SchemeRange = ({CardScheme scheme, int digits, int from, int to});

/// The card scheme (network) a [PaymentCardNumber]'s prefix belongs to.
///
/// Reported, never validated. ISO/IEC 7812 doesn't assign these ranges, the registry drifts, and some
/// ranges are contested, so this sits outside the parse guarantee.
enum CardScheme {
  /// Visa: `4`.
  visa,

  /// Mastercard: `51`-`55` and `2221`-`2720`.
  mastercard,

  /// American Express: `34` and `37`.
  americanExpress,

  /// JCB: `3528`-`3589`.
  jcb,

  /// Diners Club International: `30`, `36`, `38` and `39`. Its US and Canada `55` range routes as [mastercard],
  /// so it reads as one.
  dinersClub,

  /// Discover: `6011`, `644`-`649`, and the `622126`-`622925` UnionPay co-brand.
  discover,

  /// China UnionPay: `62`.
  unionPay,

  /// No listed scheme claims the prefix, or several do. [PaymentCardNumber.cardSchemes] separates those
  /// 2.
  unknown,
}
