// A validated card number is ASCII digits only.
// ignore_for_file: avoid-substring

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../numerics/digit.dart';
import '../numerics/digits.dart';
import '../shared/check_digits/luhn_check_digit.dart';
import '../shared/minted_format_exception.dart';
import '../shared/normalisation.dart';
import '../shared/parse_outcome.dart';
import 'failures/payment_card_number_failure.dart';

/// A payment card number: the ISO/IEC 7812 primary account number (PAN), validated for digits, the
/// 8-to-19-digit length window, and the Luhn check digit. Credit, debit, prepaid and gift cards all
/// share the numbering scheme.
/// Standard: [ISO/IEC 7812](https://en.wikipedia.org/wiki/Payment_card_number).
///
/// Normalisation on parse: spaces and hyphens are stripped, so a card's grouped form and its compact
/// form compare equal.
///
/// A class rather than an extension type so [toString] can render [masked] instead of [value]: a PAN
/// in a log line is a leak. The card scheme is reported, never validated; see [cardScheme].
///
/// {@example /example/minted_example.dart#card}
@immutable
final class PaymentCardNumber {
  /// The primary account number, digits only. The canonical form, and the one member that reveals
  /// the card, so prefer [masked] anywhere the result might be logged.
  final String value;

  const new _(this.value);

  /// Builds a [PaymentCardNumber] from an [iin] and [accountIdentifier], computing the Luhn check
  /// digit. Throws [MintedFormatException] when the parts don't form a valid number. For assembling
  /// from a known-valid source.
  static PaymentCardNumber fromComponents({
    required Digits iin,
    required Digits accountIdentifier,
  }) {
    final parts = '${iin.asString} + ${accountIdentifier.asString}';
    final assembledNumber = _withCheckDigit('${iin.asString}${accountIdentifier.asString}');
    final failure = _failureFor(assembledNumber);

    return failure != null ? throw MintedFormatException.from(failure, parts) : ._(assembledNumber);
  }

  /// Parses [input] as a payment card number, or returns `null` when it fails the length, character,
  /// or Luhn checks.
  static PaymentCardNumber? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a payment card number, reporting the [PaymentCardNumberFailure] that says
  /// which check failed.
  static ParseOutcome<PaymentCardNumberFailure, PaymentCardNumber> parse(String input) {
    final compactInput = compact(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(compactInput));
  }

  /// Which schemes claim [input]'s prefix, with no length or Luhn requirement, so a form can show a
  /// card's brand while it is still being typed (an instance cannot: partial input doesn't parse).
  ///
  /// Empty until enough digits arrive to place a range, and empty for a prefix no listed scheme
  /// claims. Two entries where a range is genuinely co-branded.
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
  // The first character of a validated number is always a digit, so tryParse cannot return null.
  Digit get majorIndustryIdentifier => .tryParse(value[0])!;

  /// The six-digit issuer identification number, or `null` when the number is too short to hold one
  /// alongside a check digit.
  String? get iin6 => value.length > _iin6Length ? value.substring(0, _iin6Length) : null;

  /// The eight-digit issuer identification number ISO/IEC 7812:2017 widened to, or `null` as [iin6].
  String? get iin8 => value.length > _iin8Length ? value.substring(0, _iin8Length) : null;

  /// The last four digits: the part receipts print and systems keep.
  String get last4 => value.substring(value.length - _last4Length);

  /// The final digit, the Luhn check over the others.
  // Always a digit in a validated number, so tryParse cannot return null.
  Digit get checkDigit => .tryParse(value[value.length - 1])!;

  /// Everything but [last4] hidden, e.g. `••••1111`. What [toString] renders, so a log line or a
  /// test failure cannot leak the number.
  String get masked => '$_maskGlyphs$last4';

  /// The schemes claiming this number's prefix; see [cardSchemesOf].
  Set<CardScheme> get cardSchemes => cardSchemesOf(value);

  /// The single scheme claiming this number, or [CardScheme.unknown] when none does or several do.
  /// Read [cardSchemes] to tell those two apart.
  CardScheme get cardScheme => cardSchemes.singleOrNull ?? .unknown;

  @override
  bool operator ==(Object other) => other is PaymentCardNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PaymentCardNumber($masked)';

  static String _withCheckDigit(String bodyDigits) => '$bodyDigits${luhnCheckDigit(bodyDigits)}';

  // Why already-compacted input is not a card number, or null when it is one. The single gate parse
  // and fromComponents funnel through; widest check first, so the earliest wrong thing is named.
  static PaymentCardNumberFailure? _failureFor(String compactInput) => switch (compactInput) {
    _ when compactInput.length < _minLength || compactInput.length > _maxLength =>
      PaymentCardNumberWrongLength(compactInput.length),
    _ when !digitsOnly.hasMatch(compactInput) => const PaymentCardNumberInvalidCharacters(),
    _ when !_checksumHolds(compactInput) => const PaymentCardNumberChecksumFailed(),
    _ => null,
  };

  static bool _checksumHolds(String compactInput) =>
      compactInput.endsWith(luhnCheckDigit(compactInput.substring(0, compactInput.length - 1)));

  // One row per range, and only ranges no other known network contests, so a contested one reads as
  // unknown rather than as a confident wrong answer. Why the full registry stays out:
  // APPENDIX.md#payment-card-number-value-type.
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

// One scheme's inclusive prefix range: that many leading digits, read as a number, from `from` to
// `to`. A scheme claiming several ranges gets a row each; the result set dedupes them.
typedef _SchemeRange = ({CardScheme scheme, int digits, int from, int to});

/// The card scheme (network) a [PaymentCardNumber]'s prefix belongs to.
///
/// Reported, never validated: ISO/IEC 7812 does not assign these ranges, the registry drifts, and
/// some ranges are contested, so this sits outside the parse guarantee.
enum CardScheme {
  /// Visa: `4`.
  visa,

  /// Mastercard: `51`-`55` and `2221`-`2720`.
  mastercard,

  /// American Express: `34` and `37`.
  americanExpress,

  /// JCB: `3528`-`3589`.
  jcb,

  /// Diners Club International: `30`, `36`, `38` and `39`. Its US and Canada `55` range routes as
  /// [mastercard], so it reads as one.
  dinersClub,

  /// Discover: `6011`, `644`-`649`, and the `622126`-`622925` UnionPay co-brand.
  discover,

  /// China UnionPay: `62`.
  unionPay,

  /// No listed scheme claims the prefix, or several do. [PaymentCardNumber.cardSchemes] separates
  /// those two.
  unknown,
}
