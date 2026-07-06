# minted

Well-modelled Dart value types for things usually left as a raw `String`: email,
IBAN, phone numbers, and more. Every type is built on **parse, don't validate**,
so an instance can only exist if it's well-formed, the guarantee `Uri` gives for
URLs.

No public constructor: build values through `tryParse` (returns `null`) or
`parse` (throws `MintedFormatException`, a `FormatException`). Pure Dart, so it
runs on Flutter, servers, CLIs, and the web.

## Install

```sh
dart pub add minted
```

## Usage

```dart
final email = Email.parse('Jane.Doe@Example.COM');
email.value;     // Jane.Doe@example.com   (domain lower-cased)
email.domain;    // example.com
email.mailtoUri; // mailto:Jane.Doe@example.com
Email.tryParse('not-an-email'); // null

final iban = Iban.parse('gb29 nwbk 6016 1331 9268 19');
iban.value;       // GB29NWBK60161331926819   (compact)
iban.countryCode; // GB
iban.formatted;   // GB29 NWBK 6016 1331 9268 19

final phone = PhoneNumber.parse('0 655 5705 76', region: 'FR');
phone.value;  // +33655570576   (E.164)
phone.type;   // PhoneNumberType.mobile
phone.telUri; // tel:+33655570576
```

Types check the real standard, not just the shape: `Iban` runs the ISO 13616
mod-97 checksum, `Email` the RFC 5322 grammar, and `PhoneNumber` resolves to
E.164 (national input takes a `region` hint, international input doesn't). They
normalise on parse, so equality is canonical. Every type shares one surface:
`tryParse` / `parse` / `.value` / value equality, plus type-specific getters.

## Roadmap

- [x] `Email` (RFC 5322)
- [x] `Iban` (ISO 13616, mod-97)
- [x] `PhoneNumber` (E.164)
- [ ] `Bic`, `CreditCardNumber` (Luhn), `Isbn`, `Ean` / `Gtin`
- Later: ISO code lists, constrained strings, opt-in JSON / `fpdart` / Flutter companions.

<details>
<summary>Scope, and IBAN country coverage</summary>

`minted` fills the gap where no clean value type exists. It doesn't re-model what
the SDK (`Uri`, `DateTime`, `BigInt`) or strong packages (`money2`, `uuid`,
`intl`) already cover. Where a good package already solves a piece, it wraps it
rather than reinventing: the email grammar, the IBAN registry, and phone
metadata all come from established packages.

IBAN country coverage comes from
[`iban_validator`](https://pub.dev/packages/iban_validator), which tracks recent
adoptions and includes some countries not yet in the formal ISO registry. Check a
given country in its [data file](https://github.com/khrisbreezy/iban_validator/blob/main/lib/src/iban_data.dart).
</details>

## License

Not yet chosen.
