[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![Coverage Status](https://coveralls.io/repos/github/LahaLuhem/minted/badge.svg?branch=main)](https://coveralls.io/github/LahaLuhem/minted?branch=main)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/LahaLuhem/minted/pulls) [![Pub Version](https://img.shields.io/pub/v/minted.svg)](https://pub.dev/packages/minted) [![Pub Points](https://img.shields.io/pub/points/minted?logo=dart)](https://pub.dev/packages/minted/score)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](./LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/LahaLuhem/minted.svg)](https://github.com/LahaLuhem/minted/issues) [![GitHub closed issues](https://img.shields.io/github/issues-closed/LahaLuhem/minted.svg)](https://github.com/LahaLuhem/minted/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/LahaLuhem/minted.svg)](https://github.com/LahaLuhem/minted/pulls) [![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/LahaLuhem/minted.svg)](https://github.com/LahaLuhem/minted/pulls?q=is%3Apr+is%3Aclosed)

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Install](#install)
- [A quick taste](#a-quick-taste)
- [What's in the box](#whats-in-the-box)
    * [Contact](#contact)
    * [Finance](#finance)
    * [Chronology](#chronology)
    * [Numerics](#numerics)
- [One shape, every type](#one-shape-every-type)
- [Roadmap](#roadmap)
- [Contributing](#contributing)

<!-- TOC end -->

**minted** gives you real types for the values you'd usually keep in a `String` and hope for the
best: emails, IBANs, phone numbers, and more. Every type is built on *parse, don't validate*, so an
instance can only exist if it's well-formed, the same guarantee `Uri` gives you for URLs. Once you
hold an `Email`, it *is* a valid email. No more carrying "is this string actually valid?" three
functions deep.

It's pure Dart, so it runs everywhere Dart does: Flutter apps, servers, CLIs, and the web. And every
type wears the same small API, so learning one teaches you the rest.

## Install

```sh
dart pub add minted
```

## A quick taste

```dart
final email = Email.parse('Jane.Doe@Example.COM');
email.value;   // 'Jane.Doe@example.com'   (domain lower-cased for you)
email.domain;  // 'example.com'

Email.tryParse('not-an-email');   // null, nothing thrown
```

## What's in the box

Grouped by domain sector, the same way the source is laid out under `lib/src/`.

### Contact

| Type | What it guarantees | Standard |
| --- | --- | --- |
| `Email` | a well-formed address, domain lower-cased | [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322) |
| `PhoneNumber` | a valid number, stored in E.164 | [ITU-T E.164](https://en.wikipedia.org/wiki/E.164) |

### Finance

| Type | What it guarantees | Standard |
| --- | --- | --- |
| `Iban` | structure, country length, and the mod-97 checksum | [ISO 13616](https://en.wikipedia.org/wiki/International_Bank_Account_Number) |

### Chronology

| Type | What it guarantees | Standard |
| --- | --- | --- |
| `Date` | a real calendar date: no time, no zone; impossible dates rejected | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) |
| `Month` | a real month `1`-`12` that knows its own length (leap-aware) | building block |

### Numerics

| Type | What it guarantees | Standard |
| --- | --- | --- |
| `Digit` / `Digits` | a single digit `0`-`9`, or an iterable sequence of them | building block |

Everything checks the *real* standard, not just the shape: `Iban` actually runs the mod-97 checksum
and `Email` the full RFC 5322 grammar. A regex that only looks right isn't enough.

## One shape, every type

Learn one type and you've learned them all. Each one gives you:

- `Type.tryParse(input)` returns the value, or `null` when the input isn't valid
- `Type.parse(input)` returns the value, or throws `MintedFormatException` (it extends
  `FormatException`, so your existing `on FormatException` handlers still catch it)
- **value equality**: `a == b` compares content, not identity
- a **canonical form** to read back (`.value` on most types, `.asString` on `Digits`), normalised on
  parse so equal values really are equal
- an assembly factory for parts you already trust (`fromComponents`, `from`, or `of`)
- getters that fit the type: `email.domain`, `iban.checkDigits`, `phone.nationalNumber`

<details>
<summary><b>More examples</b></summary>

```dart
final iban = Iban.parse('gb29 nwbk 6016 1331 9268 19');
iban.value;       // 'GB29NWBK60161331926819'   (compact)
iban.countryCode; // 'GB'
iban.checkDigits; // (first: Digit, second: Digit)
iban.formatted;   // 'GB29 NWBK 6016 1331 9268 19'   (grouped paper form)

final phone = PhoneNumber.parse('0 655 5705 76', region: 'FR');
phone.value;          // '+33655570576'   (E.164)
phone.type;           // PhoneNumberType.mobile
phone.nationalNumber; // Digits(655570576)   (an Iterable<Digit>)
phone.telUri;         // tel:+33655570576

// national-format input takes a region hint; international ('+…') input doesn't:
PhoneNumber.tryParse('0 655 5705 76');   // null (no region given)

// Date: the calendar date DateTime doesn't model (no time, no zone):
final date = Date.parse('2026-07-07');   // strict ISO 8601 YYYY-MM-DD
date.iso8601;      // '2026-07-07'   (canonical form)
date.weekday;      // 2   (1 = Monday … 7 = Sunday)
date.month;        // Month.july   (a Month; date.month.daysIn(2026) is 31)
date.addDays(30);  // Date(2026-08-06)
date < Date(2027); // true   (Date(2027) is 2027-01-01)

// impossible dates are rejected, not rolled over the way DateTime does:
Date.tryParse('2026-13-01');   // null (no 13th month; DateTime would give 2027-01-01)

// build from parts you already trust (throws if they don't form a valid whole):
Iban.fromComponents(countryCode: 'GB', bban: 'NWBK60161331926819'); // computes the check digits
Email.fromComponents(localPart: 'jane', domain: 'example.com');
PhoneNumber.fromComponents(countryCode: '33', nationalNumber: Digits.parse('655570576'));
```

</details>

<details>
<summary><b>Why "parse, don't validate"?</b></summary>

A validator takes a `String`, checks it, and hands the same `String` back, so every function
downstream has to trust the check happened, or re-check it. A parser takes a `String` and returns a
*different type* that can only exist if the input was well-formed. Validity becomes a fact of the
type system: checked once, carried everywhere.

That's what `int.parse` and `Uri.parse` already do, and it's what every `minted` type does for its
domain. `String email, String phone, String name` are three interchangeable, mixed-up-able
parameters; `Email`, `PhoneNumber`, `PersonName` are not. (Named after Alexis King's essay.)

</details>

<details>
<summary><b>Scope: what minted covers, and what it doesn't</b></summary>

`minted` fills the gap where no clean value type exists. It doesn't re-model what the SDK (`Uri`,
`DateTime`, `BigInt`) or strong packages (`money2`, `uuid`, `intl`) already cover well. Where a good
package already solves a piece, minted wraps it rather than reinventing: the email grammar, the IBAN
registry, and phone metadata all come from established packages.

IBAN country coverage comes from [`iban_validator`](https://pub.dev/packages/iban_validator), which
tracks recent adoptions and includes some countries not yet in the formal ISO registry. You can
check a given country in its
[data file](https://github.com/khrisbreezy/iban_validator/blob/main/lib/src/iban_data.dart).

</details>

## Roadmap

- [x] `Email` (RFC 5322)
- [x] `Iban` (ISO 13616, mod-97)
- [x] `PhoneNumber` (E.164)
- [x] `Date` / `Month` (ISO 8601 calendar date, leap-aware month)
- [x] `Digit` / `Digits` (numeric building blocks)
- [ ] `Bic`, `CreditCardNumber` (Luhn), `Isbn`, `Ean` / `Gtin`
- Later: ISO code lists, bounded numerics, opt-in JSON / `fpdart` / Flutter companions

## Contributing

Issues and pull requests are welcome. If you're adding a type, hold it to the shared value-type
contract (parse-don't-validate, a private constructor, `MintedFormatException`, value equality) and
bring the official standard test vectors along.
