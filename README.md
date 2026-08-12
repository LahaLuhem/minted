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
    * [Commerce](#commerce)
    * [Chronology](#chronology)
    * [Identifiers](#identifiers)
    * [Geography](#geography)
    * [Network](#network)
    * [Numerics](#numerics)
    * [Quantities](#quantities)
- [One shape, every type](#one-shape-every-type)
- [Handling failures](#handling-failures)
- [Caveats](#caveats)
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

| Type                | What it guarantees                                                              | Standard                                                                     |
|---------------------|---------------------------------------------------------------------------------|------------------------------------------------------------------------------|
| `Iban`              | structure, country length, and the mod-97 checksum                              | [ISO 13616](https://en.wikipedia.org/wiki/International_Bank_Account_Number) |
| `Bic`               | a SWIFT code: structure and a real country, folded to 11                        | [ISO 9362](https://en.wikipedia.org/wiki/ISO_9362)                           |
| `PaymentCardNumber` | digits, the 8-to-19 window, and Luhn; masked when printed                       | [ISO/IEC 7812](https://en.wikipedia.org/wiki/Payment_card_number)            |
| `Isin`              | a securities ID: charset, two-letter prefix, and Luhn over its letter expansion | [ISO 6166](https://www.iso.org/standard/78502.html)                          |

### Commerce

| Type   | What it guarantees                                                                 | Standard                                               |
|--------|------------------------------------------------------------------------------------|--------------------------------------------------------|
| `Gtin` | digits, one of the four GS1 lengths, and the mod-10 check digit; folded to GTIN-14 | [GS1 GTIN](https://www.gs1.org/standards/id-keys/gtin) |

### Chronology

| Type      | What it guarantees                                                 | Standard                                           |
|-----------|--------------------------------------------------------------------|----------------------------------------------------|
| `Date`    | a real calendar date: no time, no zone; impossible dates rejected  | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) |
| `Month`   | a real month `1`-`12` that knows its own length (leap-aware)       | building block                                     |
| `Weekday` | one of seven named days, ISO-numbered `1` (Monday) to `7` (Sunday) | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) |

### Identifiers

| Type   | What it guarantees                                                                 | Standard                                                                 |
|--------|------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| `Uuid` | a well-formed UUID; version and variant read back, Nil/Max recognised              | [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562)                       |
| `Isbn` | prefix and check digit; both generations folded to ISBN-13                         | [ISO 2108](https://www.isbn-international.org/content/what-isbn)         |
| `Imei` | fifteen digits and the Luhn check; TAC and serial read back                        | [3GPP TS 23.003](https://www.3gpp.org/DynaReport/23003.htm)              |
| `Issn` | eight characters and the mod-11 check; kept in printed `NNNN-NNNC` form            | [ISO 3297](https://www.issn.org/understanding-the-issn/what-is-an-issn/) |
| `Isni` | sixteen characters and the ISO 7064 MOD 11-2 check; says if it is also an ORCID iD | [ISO 27729](https://www.isni.org/)                                       |

### Geography

| Type            | What it guarantees                                                          | Standard                                             |
|-----------------|-----------------------------------------------------------------------------|------------------------------------------------------|
| `GeoCoordinate` | a bounded latitude and longitude; all three ISO 6709 widths read as degrees | [ISO 6709](https://en.wikipedia.org/wiki/ISO_6709)   |

### Network

| Type         | What it guarantees                                                                       | Standard                                                       |
|--------------|------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| `Hostname`   | the RFC 1123 grammar and both length limits; ASCII only, never an address                | [RFC 1123](https://www.rfc-editor.org/rfc/rfc1123#section-2.1) |
| `IpAddress`  | v4 or v6, canonicalised per RFC 5952; a leading zero refused, not read as octal          | [RFC 4291](https://www.rfc-editor.org/rfc/rfc4291)             |
| `Cidr`       | a network block: host bits must be clear, and `contains` masks rather than matching text | [RFC 4632](https://www.rfc-editor.org/rfc/rfc4632)             |
| `MacAddress` | 48 or 64 bits, four notations folded to one; the I/G and U/L bits read back              | [IEEE Std 802](https://en.wikipedia.org/wiki/MAC_address)      |

### Numerics

| Type               | What it guarantees                                      | Standard       |
|--------------------|---------------------------------------------------------|----------------|
| `Digit` / `Digits` | a single digit `0`-`9`, or an iterable sequence of them | building block |

### Quantities

| Type               | What it guarantees                                                                      | Standard         |
|--------------------|-----------------------------------------------------------------------------------------|------------------|
| `Uint`             | never negative (`0` or more); a sign, not a width, so nothing wraps                     | range constraint |
| `NaturalNumber`    | strictly above zero (`1` or more)                                                       | range constraint |
| `Uint2` … `Uint32` | one fixed machine width each (`0`-`3` up to `0`-`4294967295`), and the widths don't mix | range constraint |

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
  claiming the parts are good. `.getOrThrow()` on an outcome is the same claim, made against text:
  it throws the typed failure where `getOrNull()!` would throw it away
- getters that fit the type: `email.domain`, `iban.checkDigits`, `phone.nationalNumber`

Two exceptions, both deliberate. A few types are **classifications** rather than parsed values.
`Weekday`, `UuidVariant` and `PhoneNumberType` are enums a value type hands back, derived from
something that already parsed, so they give you named cases and an exhaustive `switch` instead of
`tryParse` / `parse`. `Weekday` still has `from` / `tryFrom` to build one from an ISO day number.

The others are **constraint types** (`Uint`, `NaturalNumber`, and the fixed widths): a range over a
number, with no standard defining a text form for one, so a `parse(String)` door would be inventing
one. They take `tryFrom(int)` instead, and with one invariant each there is nothing a failure could
say that `null` doesn't, so they carry none.

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

// Bic: the 8- and 11-character spellings of one office are the same value, XXX being the office:
final bic = Bic.tryParse('deut de ff')!;
bic.value;              // 'DEUTDEFFXXX'
bic.bic8;               // 'DEUTDEFF'   (the short form, rebuilt)
bic.countryCode;        // 'DE'
bic.isPrimaryOffice;    // true
bic.isSwiftRegistrable; // true: ISO 9362 permits shapes SWIFT itself doesn't issue

// PaymentCardNumber is a class, not an extension type, so printing one can't leak the number:
final card = PaymentCardNumber.tryParse('4111 1111 1111 1111')!;
card.masked;      // '••••1111'
'$card';          // 'PaymentCardNumber(••••1111)'
card.value;       // '4111111111111111'   (the only member that hands the number back)
card.iin6;        // '411111'   (null when the number is too short to hold one)
card.cardScheme;  // CardScheme.visa   (read off the prefix, never validated)

// the scheme also reads from partial input, so a form can show the brand while you type:
PaymentCardNumber.cardSchemesOf('4');   // {CardScheme.visa}

PaymentCardNumber.tryParse('4111111111111112');   // null: fails the Luhn check

// MacAddress: four notations spell one address, so whichever one a device, a log or a config file
// happens to use stops mattering:
final mac = MacAddress.tryParse('00-00-5E-00-53-00')!;
mac.value;                 // '00:00:5e:00:53:00'   (canonical: colon-separated, lower-case)
mac.ieee802;               // '00-00-5E-00-53-00'   (the IEEE hyphen form, for a Windows-shaped UI)
mac.bareHex;               // '00005e005300'        (for a database key or a URL)
mac.prefix24;              // '00:00:5e'   (the first three octets; deliberately not called an OUI)
mac.isMulticast;           // false   (the I/G bit)
mac.isLocallyAdministered; // false   (the U/L bit)

MacAddress.tryParse('0000.5e00.5300') == mac;   // true: Cisco's dot-quad is the same address
MacAddress.tryParse('0:0:5e:0:53:0');           // null: omitted leading zeros aren't a MAC address

// 64-bit addresses parse too, and keep their width: nothing is mapped onto anything else, so a
// 48- and a 64-bit address are never equal.
MacAddress.tryParse('00:00:5e:10:00:00:00:00')!.octetCount;   // 8

// IpAddress: four spellings of one v6 address are four different map keys as Strings. RFC 5952
// says which one is canonical, and InternetAddress can't help you: it's dart:io, so no web.
final address = IpAddress.tryParse('2001:0DB8:0:0:0:0:0:1')!;
address.value;    // '2001:db8::1'   (leading zeros gone, longest zero run compressed)
address.version;  // IpVersion.v6
address.octets;   // 16 octets (4 for a v4 address)

IpAddress.tryParse('2001:db8::1') == address;   // true
IpAddress.tryParse('10.0.0.1')!.isPrivate;      // true  (RFC 1918; fc00::/7 for v6)
IpAddress.tryParse('127.0.0.1')!.isLoopback;    // true

// a leading zero is refused rather than read, because inet_aton calls 010 octal and most
// parsers call it ten: accept it and one component can filter what another connects to.
IpAddress.parse('192.168.010.1').reasonOrNull?.message;
// '"010" has a leading zero, which is ambiguous between decimal and octal'

// Cidr: a network block, holding an IpAddress rather than the text, so contains() masks bits
// instead of matching a string prefix. The string version calls 100.0.0.1 part of 10.0.0.0/8:
final block = Cidr.tryParse('10.0.0.0/8')!;
block.network;      // IpAddress('10.0.0.0')   (a parsed address, not a substring)
block.prefixLength; // 8
block.lastAddress;  // IpAddress('10.255.255.255')
block.asString;     // '10.0.0.0/8'   (canonical form)

block.contains(IpAddress.tryParse('10.1.2.3')!);   // true
block.contains(IpAddress.tryParse('100.0.0.1')!);  // false, where a text prefix match says true
block.contains(IpAddress.tryParse('::1')!);        // false: a v6 address is never in a v4 block

// host bits set is refused rather than silently masked, and the failure offers what you meant:
Cidr.parse('192.168.1.5/24').reasonOrNull?.message;
// 'has host bits set below the prefix; the network is "192.168.1.0/24"'

// Hostname: Uri accepts -bad.com, a..b.com and a 64-character label without complaint. This
// doesn't. Case and a trailing root dot normalise away, so one name has exactly one value:
final host = Hostname.tryParse('WWW.Example.COM.')!;
host.value;   // 'www.example.com'
host.labels;  // ['www', 'example', 'com']
host.fqdn;    // 'www.example.com.'   (rebuilds the trailing dot, which names the root)

Hostname.tryParse('xn--bcher-kva.example');   // fine: an A-label is just letters and hyphens
Hostname.tryParse('bücher.example');          // null: punycode it yourself, we don't do IDNA
Hostname.tryParse('_sip.example.com');        // null: an underscore makes it a DNS name
Hostname.tryParse('192.168.1.1');             // null: that's an address, not a hostname

Hostname.parse('-bad.example').reasonOrNull?.message;   // '"-bad" opens or closes with a hyphen'

// GeoCoordinate: the swapped-argument bug is a type problem, so the pair is named at the boundary.
// ISO 6709 uses the width of the degree field as the unit selector; all three fold to degrees:
final eiffel = GeoCoordinate.tryParse('+48.8577+002.295/')!;
eiffel.latitude;    // 48.8577
eiffel.iso6709;     // '+48.8577+002.295/'   (canonical form)
eiffel.sexagesimal; // '48°51′27.72″N 2°17′42″E'   (display form)

// the same point spelled as degrees-minutes-seconds is the same value:
GeoCoordinate.tryParse('+485127.72+0021742/') == eiffel;   // true

GeoCoordinate.tryParse('+46+2/');   // null: an unpadded longitude is a different location
GeoCoordinate.from(latitude: 48.8577, longitude: 2.295);   // named, so it can't be written swapped

// build from parts you already trust (throws if they don't form a valid whole).
// a part that is only ever digits takes `Digits`, so junk can't reach the factory at all:
final prefix = Digits.parse('978').getOrThrow();   // getOrThrow: "I assert this is digits"
final body = Digits.parse('030640615').getOrThrow();

Isbn.fromComponents(prefix: prefix, body: body);   // computes the check digit
Gtin.fromBody(Digits.parse('400638133393').getOrThrow());

// parts that aren't digits stay strings, because `Digits` would be the wrong type:
Iban.fromComponents(countryCode: 'GB', bban: 'NWBK60161331926819'); // a BBAN is alphanumeric
Email.fromComponents(localPart: 'jane', domain: 'example.com');

// Uint and NaturalNumber take an int, not text, and differ by exactly one value:
Uint.tryFrom(0)?.value;    // 0    (an empty cart is a real count)
NaturalNumber.tryFrom(0);  // null (a page size of zero is not)
Uint.tryFrom(-1);          // null, not a wrap-around to a huge number the way C would

// the fixed widths bound both ends, and each width is its own type:
Uint8.tryFrom(255)?.value;  // 255
Uint8.tryFrom(256);         // null (refused, not truncated to 0)
void setNibble(Uint4 field) {}
setNibble(Uint8.tryFrom(200)!);   // compile error: a Uint8 is not a Uint4
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

`Bic` has no checksum to lean on: ISO 9362 defines none, so a well-formed code is accepted whether
or not an institution holds it. The country list comes from `phone_numbers_parser`, already here for
`PhoneNumber`, and includes `XK` for Kosovo the way SWIFT does.

`Isbn` doesn't hyphenate. The group boundaries aren't in the digits; they come from ISBN
International's range table, revised as ranges get allocated, so shipping a snapshot would mean
shipping a clock. Hyphens are accepted and stripped, and you get `value`, `prefix`, `body` and
`checkDigit`.

`PaymentCardNumber` doesn't make the brand part of the guarantee, for the same reason. ISO/IEC 7812
assigns no brand ranges, the IIN-to-network table drifts, and some ranges are genuinely contested
(`65` is claimed by both Discover and RuPay). So `cardScheme` reports only ranges no other network
claims and says `unknown` otherwise: silence means "can't say", not "not a card". It also masks
itself, printing `••••1111`, with `value` the one member that hands the number back, so a stray log
line can't leak a PAN.

`MacAddress` keeps whichever width it parsed and never converts. The IEEE Registration Authority
deprecated the EUI-48 to EUI-64 mapping outright, and it doesn't reverse anyway (a genuine EUI-64 may
carry the `FF-FE` filler legitimately), so a 48- and a 64-bit address are simply never equal. It also
does no vendor lookup, and `prefix24` is named for the bits it returns rather than an assignment it
can't prove: the first three octets are an OUI only under an MA-L assignment, and an MA-M or MA-S
address shares them with other organisations. Nor is the type called `Eui48`, which the IEEE reserves
for the individual, universally-administered subset.

`Cidr` refuses host bits rather than masking them: `192.168.1.5/24` fails instead of quietly
becoming `192.168.1.0/24`, because masking throws away an address you actually wrote, and the
failure hands you the block you probably meant. It holds an `IpAddress` and a prefix length rather
than the text, so `contains` masks bits instead of matching characters and a bad address inside a
block reports *why*. Only `address/prefixLength` parses, so a dotted netmask and a bare address are
both refused.

`IpAddress` is one type for both families, not two. A v4 and a v6 address are never equal and
neither is converted to the other, so `version` tells you which you hold, the way `MacAddress` reports
its width. An IPv4-mapped address stays v6 and keeps its `::ffff:192.0.2.1` spelling, which RFC 5952
asks for on that prefix. It carries [`ipaddr`](https://pub.dev/packages/ipaddr) for the `::` expansion
and the RFC 5952 compression, but owns the grammar itself: that engine's part checks are `int.tryParse`,
which quietly accepts `192.168.+1.1` and `192.168. 1.1`.

`Hostname` is ASCII-only on purpose. Punycode is not IDNA: RFC 5890 wants IDNA2008 validity, NFC and
the Bidi rules on top of the encoding, none of which any Dart package implements, so punycoding
`bücher.example` here would emit what that RFC calls a *fake A-label*. Encode it yourself and
`xn--bcher-kva.example` parses like any other name. It is also a hostname rather than a DNS name, so
`_sip._tcp.example.com` is refused, and it is never an address, because RFC 1123 says a host name
never takes the dotted-decimal form. The registrable-domain part is out for the usual reason: the
Public Suffix List changes weekly, and [`public_suffix`](https://pub.dev/packages/public_suffix)
already covers it.

`GeoCoordinate` is a surface coordinate: altitude and a CRS identifier are *refused*, not silently
dropped. Their sign, units and datum are all defined by the CRS, so an `altitude` field would be one
the type couldn't promise anything about, and validating a CRS needs a registry minted doesn't carry.
Parsing is strict about the fixed widths, because in ISO 6709 an unpadded longitude isn't a typo, it's
a different place. The human-readable `48°51′27.72″N` form is output-only for now, via `sexagesimal`.

`Uint` borrows a C name for something C wouldn't recognise: it constrains the *sign*, not a width, so
nothing wraps and there is no ceiling. `NaturalNumber` excludes zero, worth saying because the
convention is split (ISO 80000-2 counts `0` in, school arithmetic starts at `1`). Both exist because
that one value is load-bearing, and folding them into one pushes the check back to every call site.

The fixed widths are separate types rather than named factories on `Uint`, because that is the only
shape that type-checks: with a `Uint.w8(200)` every result is still a `Uint`, so nothing stops a byte
landing in a nibble slot. There is no `Uint64`, since Dart ints are JS doubles on the web and the
honest ceiling is 2^53-1. And a width is not a domain: a port and an IPv6 hextet are both `0`-`65535`,
so each stays its own named type rather than an alias for `Uint16`.

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
is proposed in [dart-lang/sdk#59310](https://github.com/dart-lang/sdk/issues/59310). The
class-backed types (`Date`, `Digits`, `PaymentCardNumber`) are ordinary classes, so bad casts throw
there instead. Why the erasure is
a deliberate trade rather than an oversight:
[APPENDIX.md](./APPENDIX.md#extension-type-representation).

## Contributing

Issues and pull requests are welcome, and the
[issue tracker](https://github.com/LahaLuhem/minted/issues) is where the types still to land are
kept. If you're adding one, hold it to the shared value-type contract (parse-don't-validate, a
private constructor, `MintedFormatException`, value equality) and bring the official standard test
vectors along.
