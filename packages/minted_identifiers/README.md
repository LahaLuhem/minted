[![Pub Version](https://img.shields.io/pub/v/minted_identifiers.svg)](https://pub.dev/packages/minted_identifiers)
[![Pub Points](https://img.shields.io/pub/points/minted_identifiers?logo=dart)](https://pub.dev/packages/minted_identifiers/score)
[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/LICENSE)

# minted_identifiers

Standardised identifiers as well-modelled value types.

Part of the [minted](https://github.com/LahaLuhem/minted) family: pure-Dart value types built on
*parse, don't validate*, so the parser is the only door in and anything that came through it is
well-formed by construction. Once you hold an `Isbn`, its check digit already passed.

## Install

```sh
dart pub add minted_identifiers
```

[`minted`](https://pub.dev/packages/minted) comes with it, holding the vocabulary a parse hands back
(`ParseOutcome`, `MintedFailure`), and so does
[`minted_constraints`](https://pub.dev/packages/minted_constraints) for the primitives this package's
getters return. Nothing here drags in
another domain's engine.

## What's in the box

| Type   | What it guarantees                                                                 | Standard                                                                 |
|--------|------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| `Uuid` | a well-formed UUID; version and variant read back, Nil/Max recognised              | [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562)                       |
| `Isbn` | prefix and check digit; both generations folded to ISBN-13                         | [ISO 2108](https://www.isbn-international.org/content/what-isbn)         |
| `Imei` | fifteen digits and the Luhn check; TAC and serial read back                        | [3GPP TS 23.003](https://www.3gpp.org/DynaReport/23003.htm)              |
| `Issn` | eight characters and the mod-11 check; kept in printed `NNNN-NNNC` form            | [ISO 3297](https://www.issn.org/understanding-the-issn/what-is-an-issn/) |
| `Isni` | sixteen characters and the ISO 7064 MOD 11-2 check; says if it is also an ORCID iD | [ISO 27729](https://www.isni.org/)                                       |
| `Gtin` | digits, one of the four GS1 lengths, and the mod-10 check digit; folded to GTIN-14 | [GS1 GTIN](https://www.gs1.org/standards/id-keys/gtin)                   |

Each one folds its spellings into a single canonical value, so two ways of writing one identifier
compare equal. `Uuid` is a value type rather than a generator: mint new ones with the
[`uuid`](https://pub.dev/packages/uuid) package, then type the result here.

## A quick taste

```dart
// Uuid: case, a urn:uuid: prefix, and surrounding braces all normalise away:
final id = Uuid.tryParse('URN:UUID:F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6')!;
id.value;    // 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6'
id.version;  // 1
id.variant;  // UuidVariant.rfc9562

// Isbn: both generations fold to the 13-digit value, so two spellings of one book are equal:
final isbn = Isbn.tryParse('0-306-40615-2')!;
isbn.value;   // '9780306406157'
isbn.isbn10;  // '0306406152'   (null for a 979 ISBN, which never had one)
isbn == Isbn.tryParse('978-0-306-40615-7');   // true
Isbn.tryParse('9790260000438');   // null: an ISMN, printed music rather than a book

// Gtin: all four GS1 lengths fold to 14, so a UPC-A and its EAN-13 spelling are one trade item:
final gtin = Gtin.tryParse('036000291452')!;
gtin.value;         // '00036000291452'
gtin.shortestForm;  // '036000291452'   (what the barcode carries)

// Issn keeps the hyphen ISO 3297 fixes in place, and its check character can be X, standing for ten:
Issn.tryParse('1050124x')!.value;   // '1050-124X'

// Imei runs the Luhn check the printed grouping hides, and hands back the parts:
final imei = Imei.tryParse('35-209900-176148-1')!;
imei.value;         // '352099001761481'
imei.tac.asString;  // '35209900'   (a Digits: which model, not which unit)

// Isni covers ORCID iDs, since ORCID issues from a block inside the ISNI range:
Isni.tryParse('0000-0002-1825-0097')!.isInOrcidBlock;   // true
```

The runnable version is the
[example](https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/example/minted_identifiers_example.dart).

## One shape, every type

- `Type.tryParse(input)` hands back the value, or `null` when the input isn't valid
- `Type.parse(input)` hands back a `ParseOutcome`: the value, or a typed failure (`UuidFailure`,
  `IsbnFailure`, `IssnFailure`, `IsniFailure`, `ImeiFailure`, `GtinFailure`) you can `switch` on, or
  read as a form-field message via `.reasonOrNull`. No door throws
- value equality, a canonical `.value` normalised on parse, and an assembly factory
  (`fromComponents`, `fromBody`, `fromBytes`) for parts you already hold. A part that is only ever
  digits takes a `Digits`, so junk can't reach the factory at all

The [`minted` README](https://pub.dev/packages/minted) is the family guide: the package index,
handling failures, and the one caveat (never cast into a minted type).

[APPENDIX.md](./APPENDIX.md) carries the design rationale for these types: the alternatives
that were weighed and dropped, and what each decision costs.
