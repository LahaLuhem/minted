# minted

Well-modelled Dart value types (domain primitives) for entities usually left as
a raw `String` or `int` even though they carry real validation or normalisation
rules: email, IBAN, and more.

Every type is built on **parse, don't validate**. There's no public constructor;
you build a value only through `tryParse` (returns `null` on bad input) or
`parse` (throws a typed `FormatException`). So any instance that exists is
guaranteed well-formed, the same way `Uri` guarantees a valid URL. It's a direct
antidote to primitive obsession: `Email` and `Iban` can't be swapped for each
other, or for a bare `String`, by mistake.

Pure Dart, so it runs in Flutter apps, Dart servers, CLIs, and on the web.

## Install

```sh
dart pub add minted
```

## The shape

Every type presents the same surface, so you learn it once:

| Member | Meaning |
| --- | --- |
| `T? tryParse(String)` | `null` when the input is invalid, never throws |
| `T parse(String)` | throws `MintedFormatException` (a `FormatException`) when invalid |
| `.value` | the canonical string form |
| `==` / `hashCode` | two values that normalise the same are equal |
| type-specific getters | sub-parts and render helpers |

## Usage

### Email

```dart
final email = Email.parse('Jane.Doe@Example.COM');
email.value;     // Jane.Doe@example.com   (domain lower-cased)
email.localPart; // Jane.Doe               (case preserved)
email.domain;    // example.com
email.mailtoUri; // Uri -> mailto:Jane.Doe@example.com

Email.tryParse('not-an-email'); // null
```

The address is trimmed and its domain lower-cased; the local-part case is
preserved, because RFC 5321 leaves local-part case-sensitivity to the receiving
host. So `a@Example.com == a@example.com`, but `A@example.com != a@example.com`.
The grammar check is delegated to
[`email_validator`](https://pub.dev/packages/email_validator).

### Iban

```dart
final iban = Iban.parse('gb29 nwbk 6016 1331 9268 19');
iban.value;       // GB29NWBK60161331926819   (compact, upper-cased)
iban.countryCode; // GB
iban.checkDigits; // 29
iban.bban;        // NWBK60161331926819
iban.formatted;   // GB29 NWBK 6016 1331 9268 19  (grouped for display)
```

`Iban` validates the real ISO 13616 standard, not just the shape: structure, the
country-specific length, and the mod-97 checksum. A value that parses has passed
its checksum.

> **IBAN country coverage.** The country registry (formats, lengths, and the
> mod-97 check) comes from
> [`iban_validator`](https://pub.dev/packages/iban_validator), which tracks
> recent adoptions and includes some countries not yet in the formal ISO 13616
> registry. To check whether a given country is covered, see its
> [country data](https://github.com/khrisbreezy/iban_validator/blob/main/lib/src/iban_data.dart).

### Handling failure

```dart
Email.tryParse(input); // null on failure, no throw

try {
  Iban.parse(input);
} on MintedFormatException catch (error) {
  // A FormatException, so `on FormatException` catches it too.
  print(error.message); // Invalid Iban: failed IBAN structure or mod-97 check
}
```

## What it deliberately doesn't cover

`minted` targets the gap where no clean Dart value type exists. It doesn't
re-model what the SDK or a strong package already handles well:

- **Standard library:** URLs (`Uri`), IP addresses (`InternetAddress`), dates and
  durations (`DateTime` / `Duration`), big integers (`BigInt`); in Flutter,
  `Color`, `Locale`, `TimeOfDay`.
- **Established packages:** phone numbers (`phone_numbers_parser`), money and
  decimals (`money2`, `decimal`), UUIDs (`uuid`), SemVer (`pub_semver`),
  formatting and ISO code lists (`intl`), time zones (`timezone`).

Where a good package already solves a piece (the IBAN registry, the email
grammar), `minted` wraps it behind a consistent value type rather than
reinventing it.

## Roadmap

v0.1 focuses on identifiers with real checks:

- [x] `Email` (RFC 5322 grammar)
- [x] `Iban` (ISO 13616, mod-97)
- [ ] `Bic` (ISO 9362)
- [ ] `CreditCardNumber` (Luhn)
- [ ] `Isbn` (ISBN-10 / 13 check digit)
- [ ] `Ean` / `Gtin` (GS1 check digit)

Later: ISO code lists (country, currency, language), constrained strings
(non-empty, bounded, slug), and opt-in integrations (JSON, `fpdart`, a Flutter
form-field companion) that never burden the core.

## License

Not yet chosen.
