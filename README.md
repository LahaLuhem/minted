[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![Coverage Status](https://coveralls.io/repos/github/LahaLuhem/minted/badge.svg?branch=main)](https://coveralls.io/github/LahaLuhem/minted?branch=main)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/LahaLuhem/minted/pulls)
[![Pub Version](https://img.shields.io/pub/v/minted.svg)](https://pub.dev/packages/minted)
[![Pub Points](https://img.shields.io/pub/points/minted?logo=dart)](https://pub.dev/packages/minted/score)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](./LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/LahaLuhem/minted.svg)](https://github.com/LahaLuhem/minted/issues)
[![GitHub closed issues](https://img.shields.io/github/issues-closed/LahaLuhem/minted.svg)](https://github.com/LahaLuhem/minted/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/LahaLuhem/minted.svg)](https://github.com/LahaLuhem/minted/pulls)
[![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/LahaLuhem/minted.svg)](https://github.com/LahaLuhem/minted/pulls?q=is%3Apr+is%3Aclosed)

**minted** gives you real types for the values you'd usually keep in a `String` and hope for the
best: emails, IBANs, phone numbers, and more. Every type is built on *parse, don't validate*: the
parser is the only door in, so anything that came through it is well-formed by construction. Once
you hold an `Email`, it *is* a valid email. No more carrying "is this string actually valid?" three
functions deep. (One asterisk on that, see [Caveats](#caveats).)

It's pure Dart, so it runs everywhere Dart does: Flutter apps, servers, CLIs, and the web. And every
type wears the same small API, so learning one teaches you the rest.

<details>
<summary><b>Why "parse, don't validate"?</b></summary>

A validator takes a `String`, checks it, and hands the same `String` back, so every function
downstream has to trust the check happened, or re-check it. A parser takes a `String` and returns a
*different type* that can only exist if the input was well-formed. Validity becomes a fact of the
type system: checked once, carried everywhere.

That's what `int.parse` and `Uri.parse` already do, and it's what every `minted` type does for its
domain. `String email, String phone, String name` are three interchangeable, mixed-up-able
parameters; `Email`, `PhoneNumber`, `PersonName` are not.

The phrase comes from Alexis King's essay,
[*Parse, don't validate*](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/). It's
written in Haskell, but nothing in the argument depends on that; it reads fine from Dart.

</details>

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Install](#install)
- [A quick taste](#a-quick-taste)
- [What's in the box](#whats-in-the-box)
    * [Contact](#contact)
    * [Finance](#finance)
    * [Chronology](#chronology)
    * [Identifiers](#identifiers)
    * [Numerics](#numerics)
- [One shape, every type](#one-shape-every-type)
- [Handling failures](#handling-failures)
- [Caveats](#caveats)
- [Roadmap](#roadmap)
- [Contributing](#contributing)

<!-- TOC end -->

---

## Install

```sh
dart pub add minted
```

## A quick taste

```dart
final email = Email.tryParse('Jane.Doe@Example.COM')!;
email.value;   // 'Jane.Doe@example.com'   (domain lower-cased for you)
email.domain;  // 'example.com'

Email.tryParse('not-an-email');   // null, nothing thrown
```

## What's in the box

Grouped by domain sector, the same way the source is laid out under `lib/src/`.

### Contact

| Type          | What it guarantees                        | Standard                                           |
|---------------|-------------------------------------------|----------------------------------------------------|
| `Email`       | a well-formed address, domain lower-cased | [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322) |
| `PhoneNumber` | a valid number, stored in E.164           | [ITU-T E.164](https://en.wikipedia.org/wiki/E.164) |

### Finance

| Type   | What it guarantees                                 | Standard                                                                     |
|--------|----------------------------------------------------|------------------------------------------------------------------------------|
| `Iban` | structure, country length, and the mod-97 checksum | [ISO 13616](https://en.wikipedia.org/wiki/International_Bank_Account_Number) |

### Chronology

| Type      | What it guarantees                                                | Standard                                           |
|-----------|-------------------------------------------------------------------|----------------------------------------------------|
| `Date`    | a real calendar date: no time, no zone; impossible dates rejected | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) |
| `Month`   | a real month `1`-`12` that knows its own length (leap-aware)      | building block                                     |
| `Weekday` | one of seven named days, ISO-numbered `1` (Monday) to `7` (Sunday) | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) |

### Identifiers

| Type   | What it guarantees                                                    | Standard                                                         |
|--------|-----------------------------------------------------------------------|--------------------------------------------------------------------|
| `Uuid` | a well-formed UUID; version and variant read back, Nil/Max recognised | [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562)               |
| `Isbn` | prefix and check digit; both generations folded to ISBN-13            | [ISO 2108](https://www.isbn-international.org/content/what-isbn) |

### Numerics

| Type               | What it guarantees                                      | Standard       |
|--------------------|---------------------------------------------------------|----------------|
| `Digit` / `Digits` | a single digit `0`-`9`, or an iterable sequence of them | building block |

Everything checks the *real* standard, not just the shape: `Iban` actually runs the mod-97 checksum
and `Email` the full RFC 5322 grammar. A regex that only looks right isn't enough.

## One shape, every type

Learn one type and you've learned them all. Each one gives you:

- `Type.tryParse(input)` returns the value, or `null` when the input isn't valid
- `Type.parse(input)` returns a `ParseOutcome`: either the value, or a typed `failure` from that
  type's own vocabulary (`IbanFailure`, `DateFailure`, …). Nothing is thrown, so you can `switch`
  on the cause, or read `.reasonOrNull` for a form-field message
- **value equality**: `a == b` compares content, not identity
- a **canonical form** to read back (`.value` on most types, `.asString` on `Digits`), normalised on
  parse so equal values really are equal
- an **assembly factory** for parts you assert are valid (`fromComponents`, `from`, `of`). These
  *do* throw `MintedFormatException`, which extends `FormatException`, because calling one is you
  claiming the parts are good
- getters that fit the type: `email.domain`, `iban.checkDigits`, `phone.nationalNumber`

One exception, and it's deliberate: a few types are **classifications** rather than parsed values.
`Weekday`, `UuidVariant` and `PhoneNumberType` are enums a value type hands back, derived from
something that already parsed, so they give you named cases and an exhaustive `switch` instead of
`tryParse` / `parse`. `Weekday` still has `from` / `tryFrom` to build one from an ISO day number.

<details>
<summary><b>More examples</b></summary>

```dart
final iban = Iban.tryParse('gb29 nwbk 6016 1331 9268 19')!;
iban.value;       // 'GB29NWBK60161331926819'   (compact)
iban.countryCode; // 'GB'
iban.checkDigits; // (first: Digit, second: Digit)
iban.formatted;   // 'GB29 NWBK 6016 1331 9268 19'   (grouped paper form)

final phone = PhoneNumber.tryParse('0 655 5705 76', region: 'FR')!;
phone.value;          // '+33655570576'   (E.164)
phone.type;           // PhoneNumberType.mobile
phone.nationalNumber; // Digits(655570576)   (an Iterable<Digit>)
phone.telUri;         // tel:+33655570576

// national-format input takes a region hint; international ('+…') input doesn't:
PhoneNumber.tryParse('0 655 5705 76');   // null (no region given)

// Date: the calendar date DateTime doesn't model (no time, no zone):
final date = Date.tryParse('2026-07-07')!;   // strict ISO 8601 YYYY-MM-DD
date.iso8601;      // '2026-07-07'   (canonical form)
date.weekday;      // Weekday.tuesday   (.value is 2, matching DateTime.weekday)
date.month;        // Month.july   (a Month; date.month.daysIn(2026) is 31)
date.addDays(30);  // Date(2026-08-06)   (throws past the 0000-9999 bound)
date.tryAddDays(3000000); // null        (the same walk, without the throw)
date < Date(2027); // true   (Date(2027) is 2027-01-01)
Date.now();        // today in the local zone, the date-only DateTime.now()

// Weekday: seven named days, so a switch over one needs no default arm:
date.weekday.next;                         // Weekday.wednesday   (wraps past Sunday)
Weekday.friday.daysUntil(Weekday.monday);  // 3   (counts forward round the week)
Weekday.from(DateTime.now().weekday);      // bridges back from dart:core

// impossible dates are rejected, not rolled over the way DateTime does:
Date.tryParse('2026-13-01');   // null (no 13th month; DateTime would give 2027-01-01)

// Uuid: type an existing UUID (the `uuid` package generates them). Case, a urn:uuid: prefix,
// and surrounding braces are all normalised away:
final id = Uuid.tryParse('URN:UUID:F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6')!;
id.value;    // 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6'   (lower-cased, unwrapped)
id.version;  // 1
id.variant;  // UuidVariant.rfc9562
Uuid.tryParse('not-a-uuid');   // null

// Isbn: both generations fold to the same 13-digit value, so two spellings of one book are equal:
final isbn = Isbn.tryParse('0-306-40615-2')!;
isbn.value;    // '9780306406157'
isbn.isbn10;   // '0306406152'   (null for a 979 ISBN, which never had one)
isbn == Isbn.tryParse('978-0-306-40615-7');   // true

Isbn.tryParse('9790260000438');   // null: an ISMN, printed music rather than a book

// build from parts you already trust (throws if they don't form a valid whole):
Iban.fromComponents(countryCode: 'GB', bban: 'NWBK60161331926819'); // computes the check digits
Isbn.fromComponents(prefix: '978', body: '030640615');              // same, for a publisher
Email.fromComponents(localPart: 'jane', domain: 'example.com');
PhoneNumber.fromComponents(countryCode: '33', nationalNumber: Digits.tryParse('655570576')!);
```

</details>

<details>
<summary><b>Scope: what minted covers, and what it doesn't</b></summary>

`minted` fills the gap where no clean value type exists. It doesn't re-model what the SDK (`Uri`,
`DateTime`, `BigInt`) or strong packages (`money2`, `intl`) already cover well. Where a good
package already solves a piece, minted wraps it rather than reinventing: the email grammar, the IBAN
registry, and phone metadata all come from established packages.

`Uuid` is a value type, not a generator. The `uuid` package mints new UUIDs and hands you a
`String`; minted's `Uuid` types an existing one so it stops being a bare `String` a few functions
deep. They pair up: generate with `uuid`, then type the result with `Uuid`.

IBAN country coverage comes from [`iban_validator`](https://pub.dev/packages/iban_validator), which
tracks recent adoptions and includes some countries not yet in the formal ISO registry. You can
check a given country in its
[data file](https://github.com/khrisbreezy/iban_validator/blob/main/lib/src/iban_data.dart).

`Isbn` doesn't hyphenate. The group boundaries aren't in the digits; they come from ISBN
International's range table, revised as ranges get allocated, so shipping a snapshot would mean
shipping a clock. Hyphens are accepted and stripped, and you get `value`, `prefix`, `body` and
`checkDigit`.

</details>

## Handling failures

`parse` doesn't throw. It hands back a `ParseOutcome`: either the value, or a typed failure from
that type's own vocabulary. For a form field, `reasonOrNull` is the whole validator, because it's
`null` exactly when the input was good:

```dart
String? ibanError(String input) => switch (Iban.parse(input).reasonOrNull) {
  null => null,   // valid
  IbanChecksumFailed()                    => 'Check the digits, one looks mistyped',
  IbanUnknownCountry(:final countryCode)  => 'We do not support IBANs from $countryCode',
  IbanInvalidLength(:final expected)      => 'An IBAN here is $expected characters',
  _                                       => 'That does not look like an IBAN',
};
```

The vocabulary is sized to what the standard can actually distinguish, so it varies by type: `Iban`
has five variants, `Date` four, `Email` one. That last is the honest ceiling rather than a shortcut,
since the underlying validator reports only pass or fail, and a guessed "invalid domain" would be
worse than saying less. Switching is exhaustive per type, so adding a variant is a compile error at
your call site, not a silent gap.

Pattern-match the outcome itself when you want the value too:

```dart
switch (Iban.parse(input)) {
  case ParseSuccess(:final value): send(value);
  case ParseFailure(:final reason): log(reason.message);
}
```

Three other doors, when you don't need the reason:

| You want                                 | Use                                    | On failure                         |
|------------------------------------------|----------------------------------------|------------------------------------|
| The value or nothing                     | `Iban.tryParse(input)`                 | `null`                             |
| The value or a fallback                  | `Iban.parse(input).getOrElse(() => …)` | the fallback                       |
| To assemble from parts you already trust | `Iban.fromComponents(…)`               | **throws** `MintedFormatException` |

That last row is the only thing in the package that throws, and deliberately: calling it is *you*
asserting the parts are valid, so a failure is a bug in your code rather than bad input. The
exception extends `FormatException` and carries the same typed `failure`.

<details>
<summary><b>Using an FP library? Three lines.</b></summary>

`ParseOutcome` is `Either`-shaped on purpose, but minted doesn't depend on an FP package: that
dependency would show up in every signature and force itself on everyone. Bridge it in your own app
instead. With [`ribs_core`](https://pub.dev/packages/ribs_core):

```dart
extension RibsOutcome<F extends MintedFailure, T> on ParseOutcome<F, T> {
  Either<F, T>       get either    => fold(Either.left, Either.right);
  ValidatedNel<F, T> get validated => fold(Validated.invalidNel, Validated.validNel);
}
```

The same shape works for any other FP library: `fold` is the exit.

</details>

## Caveats

**Never cast into a minted type.** The single-value types are `extension type`s, which is what makes
them free: no allocation per value, and equality, `hashCode` and ordering inherited from the
representation. The price is that the type exists only at compile time, so a cast slips past the
parser and the compiler allows it.

```dart
'nope' as Email;             // compiles, succeeds
json['email'] as Email;      // same hole, where unvalidated input actually arrives
rawStrings as List<Email>;   // a whole list at once, no per-element check
```

That `Email` blows up the moment you read `.localPart`. So `parse`, `tryParse` and `fromComponents`
are the only doors in, and a cast into a minted type is a bug. It's also the one place the
`int.parse` / `Uri.parse` comparison breaks down, since those return real classes that can't be
forged; worth saying out loud, because a package can't stop its callers from casting. A lint for it
is proposed in [dart-lang/sdk#59310](https://github.com/dart-lang/sdk/issues/59310). The multi-part
types (`Date`, `Digits`) are ordinary classes, so bad casts throw there instead. Why the erasure is
a deliberate trade rather than an oversight:
[APPENDIX.md](./APPENDIX.md#extension-type-representation).

## Roadmap

- [x] `Email` (RFC 5322)
- [x] `Iban` (ISO 13616, mod-97)
- [x] `PhoneNumber` (E.164)
- [x] `Date` / `Month` (ISO 8601 calendar date, leap-aware month)
- [x] `Digit` / `Digits` (numeric building blocks)
- [x] `Uuid` (RFC 9562: parse, classify version/variant, Nil/Max sentinels)
- [x] `Isbn` (ISO 2108: both generations, mod-11 and GS1 mod-10, folded to ISBN-13)
- [ ] `Bic`, `CreditCardNumber` (Luhn), `Ean` / `Gtin`
- [ ] `Isbn` hyphenation, once the ISBN range table has somewhere to live
- Later: ISO code lists, bounded numerics, opt-in JSON / `fpdart` / Flutter companions

## Contributing

Issues and pull requests are welcome. If you're adding a type, hold it to the shared value-type
contract (parse-don't-validate, a private constructor, `MintedFormatException`, value equality) and
bring the official standard test vectors along.
