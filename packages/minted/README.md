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

**minted** is a family. This package holds the vocabulary every type speaks (`ParseOutcome`,
`MintedFailure`); the types themselves live in sibling packages you add one at a time, so a project
that wants `Date` doesn't resolve the phone-number metadata. [Install](#install) says which package
holds what, and each sibling documents its own types.

> Coming from 2.x, where one package held everything?
> [MIGRATION.md](./MIGRATION.md#migrating-to-minted-300) is the path: no type or behaviour changed,
> so it's a dependency and import edit the compiler walks you through. From 1.x, start
> [one section down](./MIGRATION.md#migrating-to-minted-200): that's the release where no door
> throws any more.

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
- [One shape, every type](#one-shape-every-type)
- [Handling failures](#handling-failures)
- [Caveats](#caveats)
- [Contributing](#contributing)

<!-- TOC end -->

---

## Install

Add the packages you want. Each brings `minted` with it, so there's nothing else to wire up.

```sh
dart pub add minted_constraints  # Digit, Digits, Uint tower, Char, Letter, Ascii*
dart pub add minted_contact      # Email, PhoneNumber
dart pub add minted_finance      # Iban, Bic, Isin, PaymentCardNumber
dart pub add minted_chronology   # Date, Month, Weekday, Iso8601Duration
dart pub add minted_identifiers  # Uuid, Isbn, Issn, Isni, Imei, Gtin
dart pub add minted_geography    # GeoCoordinate, Geohash
dart pub add minted_network      # IpAddress, Cidr, Hostname, DnsName, MacAddress, Port
```

`dart pub add minted` on its own gets you the outcome types and nothing else: no domain engine is
behind it. Add it directly only if you name `ParseOutcome` or a failure yourself.

## A quick taste

```dart
// Email comes from minted_contact; every domain type is imported from its own package.
final email = Email.tryParse('Jane.Doe@Example.COM')!;
email.value;   // 'Jane.Doe@example.com'   (domain lower-cased for you)
email.domain;  // 'example.com'

// the domain is a String because it isn't always a hostname (address literals, IDNs):
email.domainAsHostname().getOrNull();   // Hostname('example.com'), null for those

Email.tryParse('not-an-email');   // null, nothing thrown
```

## What's in the box

`minted` itself holds the vocabulary a parse hands back: `ParseOutcome`, `MintedFailure` and
`MintedFormatError`. Every type lives in a sibling, each documenting its own in one place rather
than a second copy here:

- [`minted_constraints`](https://pub.dev/packages/minted_constraints) — the primitives the rest are
  cut from: digits, bounded numbers, single characters, and letters
- [`minted_chronology`](https://pub.dev/packages/minted_chronology) — calendar dates and durations
- [`minted_contact`](https://pub.dev/packages/minted_contact) — email addresses and phone numbers
- [`minted_finance`](https://pub.dev/packages/minted_finance) — IBANs, BICs, ISINs, card numbers
- [`minted_geography`](https://pub.dev/packages/minted_geography) — coordinates and geohashes
- [`minted_identifiers`](https://pub.dev/packages/minted_identifiers) — UUIDs, ISBNs, IMEIs, and kin
- [`minted_network`](https://pub.dev/packages/minted_network) — addresses, blocks, host names, ports

Each sibling's README is the place to look for its own runnable examples, the standard behind each
type, and the per-type caveats: what a type refuses, what it only reports, and what it leaves
deliberately unmodelled.

Everything checks the *real* standard, not just the shape: `Iban` actually runs the mod-97 checksum
and `Email` the full RFC 5322 grammar. A regex that only looks right isn't enough.

## One shape, every type

Learn one type and you've learned them all. Each one gives you:

- `Type.tryParse(input)` returns the value, or `null` when the input isn't valid
- `Type.parse(input)` returns a `ParseOutcome`: either the value, or a typed `failure` from that
  type's own vocabulary (`IbanFailure`, `DateFailure`, …), which ships in the same package as the
  type. Nothing is thrown, so you can `switch` on the cause, or read `.reasonOrNull` for a
  form-field message
- **value equality**: `a == b` compares content, not identity
- a **canonical form** to read back (`.value` on most types, `.asString` on `Digits`), normalised on
  parse so equal values really are equal
- an **assembly factory** for parts you already have (`fromComponents`, `fromBody`, `fromBytes`),
  returning the same `ParseOutcome` as `parse`. Nothing in the package throws unless you ask:
  `.getOrThrow()` is you claiming the parts are good, and it raises the typed failure where
  `getOrNull()!` would throw it away
- getters that fit the type: `email.domain`, `iban.checkDigits`, `phone.nationalNumber`

Two exceptions, both deliberate. A few types are **classifications** rather than parsed values.
`Weekday`, `UuidVariant` and `PhoneNumberType` are enums a value type hands back, derived from
something that already parsed, so they give you named cases and an exhaustive `switch` instead of
`tryParse` / `parse`. `Weekday` still has `from` / `tryFrom` to build one from an ISO day number.

The others are **constraint types** (`Uint`, `NaturalNumber`, the fixed widths, and `Percentage`):
a number with a constraint on it, and no standard defining a text form for one, so a `parse(String)`
door would be inventing one. They take `tryFrom` instead, and with one invariant each there is
nothing a failure could say that `null` doesn't, so they carry none. `Percentage` is the odd one
out: it constrains the *unit* rather than a range, so it takes both `tryFrom(15)` and
`tryFromFraction(0.15)`. `Probability` needs only one door, because its `0`-`1` range states the
convention that `Percentage` has to name.

<details>
<summary><b>Scope: what minted covers, and what it doesn't</b></summary>

`minted` fills the gap where no clean Dart value type exists. It doesn't re-model what the SDK
(`Uri`, `DateTime`, `BigInt`) or a strong package (`money2`, `intl`, `pub_semver`, `timezone`)
already covers well, and where one of those solves a piece it gets wrapped rather than reinvented:
the email grammar, the IBAN registry and the phone metadata all come from established packages.

The apparent overlaps are the interesting part. `DateTime` models an *instant*, so a plain calendar
date has no SDK type and `Date` fills it. The `uuid` package *generates* into a `String`, so `Uuid`
types what it hands back. `InternetAddress` lives in `dart:io` and is therefore off the table for a
web-safe package, which is what `IpAddress` is for. The full list, and the reasoning type by type:
[APPENDIX](https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#what-not-covered).

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

| You want               | Use                                    | On failure                     |
|------------------------|----------------------------------------|--------------------------------|
| The value or nothing   | `Iban.tryParse(input)`                 | `null`                         |
| The value or a default | `Iban.parse(input).getOrElse(() => x)` | the default                    |
| The value, asserted    | `Iban.parse(input).getOrThrow()`       | **throws** `MintedFormatError` |

That last row is the only thing in the package that throws, and only because you typed it: calling
`getOrThrow` is *you* asserting the value is valid, so a failure is a bug in your code rather than
bad input. It is an `Error` for that reason, so `on FormatException` will not catch it, and it
carries the same typed `failure`. Every other door reports instead, assembly factories included.

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
parser, and the compiler allows it.

```dart
'nope' as Email;             // compiles, succeeds
json['email'] as Email;      // same hole, where unvalidated input actually arrives
rawStrings as List<Email>;   // a whole list at once, no per-element check
```

That `Email` blows up the moment you read `.localPart`. So `parse`, `tryParse` and `fromComponents`
are the only doors in, and a cast into a minted type is a bug. It's also the one place the
`int.parse` / `Uri.parse` comparison breaks down, since those return real classes that can't be
forged; worth saying out loud, because a package can't stop its callers from casting. Lint for it
is proposed in [dart-lang/sdk#59310](https://github.com/dart-lang/sdk/issues/59310). The
class-backed types (`Date`, `Digits`, `PaymentCardNumber`) are ordinary classes, so bad casts throw
there instead. Why the erasure is
a deliberate trade rather than an oversight:
[APPENDIX.md](../../APPENDIX.md#extension-type-representation).

## Contributing

Issues and pull requests are welcome, and the
[issue tracker](https://github.com/LahaLuhem/minted/issues) is where the types still to land are
kept. If you're adding one, hold it to the shared value-type contract (parse-don't-validate, a
private constructor, an outcome-returning door, value equality) and bring the official standard test
vectors along.
