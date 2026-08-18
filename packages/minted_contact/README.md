[![Pub Version](https://img.shields.io/pub/v/minted_contact.svg)](https://pub.dev/packages/minted_contact)
[![Pub Points](https://img.shields.io/pub/points/minted_contact?logo=dart)](https://pub.dev/packages/minted_contact/score)
[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/LahaLuhem/minted/blob/main/packages/minted_contact/LICENSE)

# minted_contact

Email addresses and phone numbers as well-modelled value types.

Part of the [minted](https://github.com/LahaLuhem/minted) family: pure-Dart value types built on
*parse, don't validate*, so the parser is the only door in and anything that came through it is
well-formed by construction. Once you hold an `Email`, it *is* a valid email.

## Install

```sh
dart pub add minted_contact
```

[`minted`](https://pub.dev/packages/minted) comes with it, holding the vocabulary a parse hands back
(`ParseOutcome`, `MintedFailure`), and so does
[`minted_constraints`](https://pub.dev/packages/minted_constraints) for the primitives this package's
getters return. Nothing here drags in
another domain's engine.

## What's in the box

| Type          | What it guarantees                        | Standard                                           |
|---------------|-------------------------------------------|----------------------------------------------------|
| `Email`       | a well-formed address, domain lower-cased | [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322) |
| `PhoneNumber` | a valid number, stored in E.164           | [ITU-T E.164](https://en.wikipedia.org/wiki/E.164) |

Both check the real standard rather than a shape: the full RFC 5322 grammar, and phone metadata per
region. `PhoneNumberType` is re-exported, so reading `phone.type` doesn't mean importing the engine
behind it.

## A quick taste

```dart
final email = Email.tryParse('Jane.Doe@Example.COM')!;
email.value;      // 'Jane.Doe@example.com'   (domain lower-cased for you)
email.domain;     // 'example.com'
email.mailtoUri;  // mailto:Jane.Doe@example.com

Email.tryParse('not-an-email');   // null, nothing thrown

// the domain is a String because it isn't always a hostname (address literals, IDNs):
email.domainAsHostname().getOrNull();   // Hostname('example.com'), null for those

// PhoneNumber normalises to E.164. National-format input takes a region hint;
// international ('+…') input doesn't:
final phone = PhoneNumber.tryParse('0 655 5705 76', region: 'FR')!;
phone.value;   // '+33655570576'
phone.type;    // PhoneNumberType.mobile
phone.telUri;  // tel:+33655570576

PhoneNumber.tryParse('0 655 5705 76');   // null, no region given
```

The runnable version is the
[example](https://github.com/LahaLuhem/minted/blob/main/packages/minted_contact/example/minted_contact_example.dart).
`Email.domainAsHostname` is why this package carries
[`minted_network`](https://pub.dev/packages/minted_network) too.

## One shape, every type

- `Type.tryParse(input)` hands back the value, or `null` when the input isn't valid
- `Type.parse(input)` hands back a `ParseOutcome`: the value, or a typed failure (`EmailFailure`,
  `PhoneNumberFailure`) you can `switch` on, or read as a form-field message via `.reasonOrNull`.
  No door throws
- value equality, a canonical `.value` normalised on parse, and `fromComponents` for parts you
  already hold

The [`minted` README](https://pub.dev/packages/minted) is the family guide: the package index,
handling failures, and the one caveat (never cast into a minted type).
