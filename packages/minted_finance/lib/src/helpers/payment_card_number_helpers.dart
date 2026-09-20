// Helper file
// A validated card number is ASCII digits only.
// ignore_for_file: prefer-match-file-name, avoid-substring

part of '../payment_card_number.dart';

String _withCheckDigit(String bodyDigits) => '$bodyDigits${luhnCheckDigit(bodyDigits)}';

// The one gate parse and fromComponents both go through. Widest check first, so the earliest wrong
// thing gets named.
PaymentCardNumberFailure? _failureFor(String compactInput) => switch (compactInput) {
  _ when compactInput.length < _minLength || compactInput.length > _maxLength =>
    PaymentCardNumberWrongLength(compactInput.length),
  _ when !digitsOnly.hasMatch(compactInput) => const PaymentCardNumberInvalidCharacters(),
  _ when !_checksumHolds(compactInput) => const PaymentCardNumberChecksumFailed(),
  _ => null,
};

bool _checksumHolds(String compactInput) =>
    compactInput.endsWith(luhnCheckDigit(compactInput.substring(0, compactInput.length - 1)));

// Only ranges no other known network contests, so a contested one reads as unknown rather than as
// a confident wrong answer. Why the full registry stays out: APPENDIX.md#payment-card-number-value-type.
const _schemeRanges = <({CardScheme scheme, int digits, int from, int to})>{
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

const _minLength = 8;
const _maxLength = 19;
const _iin6Length = 6;
const _iin8Length = 8;
const _last4Length = 4;
const _maskGlyphs = '••••';

/// The card scheme (network) a [PaymentCardNumber]'s prefix belongs to.
///
/// Reported, never validated. ISO/IEC 7812 doesn't assign these ranges, the registry drifts, and some
/// ranges are contested, so this sits outside the parse guarantee.
enum CardScheme() {
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
