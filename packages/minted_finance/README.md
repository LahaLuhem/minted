[![Pub Version](https://img.shields.io/pub/v/minted_finance.svg)](https://pub.dev/packages/minted_finance)
[![Pub Points](https://img.shields.io/pub/points/minted_finance?logo=dart)](https://pub.dev/packages/minted_finance/score)
[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/LahaLuhem/minted/blob/main/packages/minted_finance/LICENSE)

# minted_finance

IBANs, BICs, ISINs and payment card numbers as well-modelled value types.

Part of the [minted](https://github.com/LahaLuhem/minted) family: pure-Dart value types built on
*parse, don't validate*, so the parser is the only door in and anything that came through it is
well-formed by construction. Once you hold an `Iban`, it *is* a checksum-valid IBAN.

## Install

```sh
dart pub add minted_finance
```

[`minted`](https://pub.dev/packages/minted) comes with it, holding the vocabulary a parse hands back
(`ParseOutcome`, `MintedFailure`), and so does
[`minted_constraints`](https://pub.dev/packages/minted_constraints) for the primitives this package's
getters return. Nothing here drags in
another domain's engine.

## What's in the box

| Type                | What it guarantees                                                              | Standard                                                                     |
|---------------------|---------------------------------------------------------------------------------|------------------------------------------------------------------------------|
| `Iban`              | structure, country length, and the mod-97 checksum                              | [ISO 13616](https://en.wikipedia.org/wiki/International_Bank_Account_Number) |
| `Bic`               | a SWIFT code: structure and a real country, folded to 11                        | [ISO 9362](https://en.wikipedia.org/wiki/ISO_9362)                           |
| `PaymentCardNumber` | digits, the 8-to-19 window, and Luhn; masked when printed                       | [ISO/IEC 7812](https://en.wikipedia.org/wiki/Payment_card_number)            |
| `Isin`              | a securities ID: charset, two-letter prefix, and Luhn over its letter expansion | [ISO 6166](https://www.iso.org/standard/78502.html)                          |

The check digits actually run: `Iban` computes mod-97 rather than matching a country's shape, and
`PaymentCardNumber` is a class rather than an `extension type` precisely so printing one can't leak
a PAN.

## A quick taste

```dart
final iban = Iban.tryParse('gb29 nwbk 6016 1331 9268 19')!;
iban.value;        // 'GB29NWBK60161331926819'   (compact)
iban.countryCode;  // 'GB'
iban.checkDigits;  // (first: Digit, second: Digit)
iban.formatted;    // 'GB29 NWBK 6016 1331 9268 19'   (grouped paper form)

// Bic: the 8- and 11-character spellings of one office are the same value, XXX being the office:
final bic = Bic.tryParse('deut de ff')!;
bic.value;                        // 'DEUTDEFFXXX'
bic.bic8;                         // 'DEUTDEFF'   (the short form, rebuilt)
bic == Bic.tryParse('DEUTDEFFXXX');  // true
Bic.tryParse('DEUTZZFF');         // null: ZZ is not a country

// PaymentCardNumber masks itself, so a stray log line can't leak the number:
final card = PaymentCardNumber.tryParse('4111 1111 1111 1111')!;
'$card';          // 'PaymentCardNumber(••••1111)'
card.value;       // '4111111111111111'   (the only member that hands the number back)
card.cardScheme;  // CardScheme.visa   (read off the prefix, never validated)

// the scheme also reads from partial input, so a form can show the brand while you type:
PaymentCardNumber.cardSchemesOf('4');             // {CardScheme.visa}
PaymentCardNumber.tryParse('4111111111111112');   // null: fails the Luhn check

// Isin runs Luhn over the number with each letter expanded to two digits:
final isin = Isin.tryParse('au0000xvgza3')!;
isin.value;              // 'AU0000XVGZA3'
isin.nsin;               // '0000XVGZA'
Isin.tryParse('US0378331006');   // null: fails the Luhn check
```

The runnable version is the
[example](https://github.com/LahaLuhem/minted/blob/main/packages/minted_finance/example/minted_finance_example.dart).

## One shape, every type

- `Type.tryParse(input)` hands back the value, or `null` when the input isn't valid
- `Type.parse(input)` hands back a `ParseOutcome`: the value, or a typed failure (`IbanFailure`,
  `BicFailure`, `IsinFailure`, `PaymentCardNumberFailure`) you can `switch` on, or read as a
  form-field message via `.reasonOrNull`. No door throws
- value equality, a canonical `.value` normalised on parse, and `fromComponents` for parts you
  already hold

The [`minted` README](https://pub.dev/packages/minted) is the family guide: the package index,
handling failures, and the one caveat (never cast into a minted type).

[APPENDIX.md](./APPENDIX.md) carries the design rationale for these types: the alternatives
that were weighed and dropped, and what each decision costs.
