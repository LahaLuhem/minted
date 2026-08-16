# Migrating minted

Newest first. [3.0.0](#migrating-to-minted-300) splits the package up;
[2.0.0](#migrating-to-minted-200) removed every implicit throw.

## Migrating to minted 3.0.0

The domain types moved into packages of their own, so you pay only for the domains you use. **No
type, method or behaviour changed**: this is a dependency and import edit, and the compiler finds
every site.

`minted` keeps the shared vocabulary: `ParseOutcome`, `MintedFailure`, `MintedFormatError`,
`Digit`, `Digits`, the `Uint` tower, `NaturalNumber`, `Percentage`, `Probability`.

| Add this package | For |
|---|---|
| `minted_chronology` | `Date`, `Month`, `Weekday`, `Iso8601Duration` |
| `minted_contact` | `Email`, `PhoneNumber`, `PhoneNumberType` |
| `minted_finance` | `Iban`, `Bic`, `Isin`, `PaymentCardNumber` |
| `minted_geography` | `GeoCoordinate` |
| `minted_identifiers` | `Uuid`, `Isbn`, `Issn`, `Isni`, `Imei`, `Gtin` |
| `minted_network` | `IpAddress`, `Cidr`, `Hostname`, `DnsName`, `MacAddress`, `Port` |

Each failure vocabulary travels with its type: `IbanFailure` is in `minted_finance`, `DateFailure`
in `minted_chronology`, and so on.

```yaml
dependencies:
  minted: ^3.0.0          # only if you use the shared vocabulary directly
  minted_finance: ^1.0.0  # for Iban and friends
```

```dart
import 'package:minted_finance/minted_finance.dart';  // was package:minted/minted.dart
```

Each domain package depends on `minted`, so you can drop the direct `minted` line unless you name
its types yourself. Nothing else changes: `Iban.parse` still returns
`ParseOutcome<IbanFailure, Iban>`.

**Why.** Depending on `minted` used to mean resolving every engine behind every type: a project
using only `Date` still pulled the phone-number metadata, the IBAN registry and the rest. Splitting
by domain makes the dependency match the use. `Gtin` also moved from commerce to
`minted_identifiers`, where it sits beside `Isbn`, since an ISBN-13 *is* a GTIN-13 and the two share
a check digit.

## Migrating to minted 2.0.0

2.0.0 removes every implicit throw. A door that can fail says so in its return type, so the compiler
points at each place that needs a decision instead of leaving it to a stack trace at runtime.

It lands in two steps. **1.1.0 deprecates everything that is going**, so a warning-free build on
1.1.0 is most of the work. **2.0.0 changes return types**, which no deprecation can warn about, so
that part is [step 2](#step-2-once-on-200).

Rationale, and the alternatives that were weighed and dropped, live in
[issue #44](https://github.com/LahaLuhem/minted/issues/44).

### The short version

Every door that used to throw behaves exactly as before if you append `.getOrThrow()`:

```dart
Isbn.fromComponents(prefix: prefix, body: body);               // 1.x
Isbn.fromComponents(prefix: prefix, body: body).getOrThrow();  // 2.0.0, same throw
```

Do that at every call site and 2.0.0 runs like 1.x, with the throw now visible in your own source.
Then revisit the ones where branching beats throwing, which is the point of the change.

### Step 1, on 1.1.0

Everything here is deprecated, so the analyzer lists each call site for you.

| 1.x                                               | Use instead                                         |
|---------------------------------------------------|-----------------------------------------------------|
| `Date(2026, 7, 7)`                                | `Date.of(2026, 7, 7)`                               |
| `date.addDays(n)`, `date.subtractDays(n)`         | `date.tryAddDays(n)`, `date.trySubtractDays(n)`     |
| `Digit.parse(s)`, `Digit.tryParse(s)`             | `Digit.tryFrom(int.parse(s))`                       |
| `Digit.from(n)`                                   | `Digit.tryFrom(n)`                                  |
| `Digits.parse(s)`, `Digits.tryParse(s)`           | `Digits.tryFrom([1, 2, 3])`                         |
| `Digits.from(values)`                             | `Digits.tryFrom(values.toList())`                   |
| `Month.from(n)`, `Weekday.from(n)`                | `Month.tryFrom(n)`, `Weekday.tryFrom(n)`            |
| `Email.fromDomainLabels(...)`                     | `Email.fromComponents(domain: labels.join('.'), …)` |
| `DigitFailure`, `DigitsFailure`, `WeekdayFailure` | nothing produces them now; drop the arms            |

Two of those are worth a sentence rather than a row.

**The `tryFrom` doors return `T?` where the old ones threw**, so a call that relied on the throw
becomes `Digit.tryFrom(n)!`. That is the same assertion, spelled where you make it.

**`Digit` and `Digits` lose their text doors for good.** Decimal notation is how numbers are
written, not a published format for "a digit sequence", so parsing one from text is the caller's
job: `int.parse` first, then `tryFrom`. Their failure vocabularies go with the doors, which is why
the last row above has no replacement.

### Step 2, once on 2.0.0

#### Doors return an outcome

Twenty doors keep their names and change their return type from `T` to `ParseOutcome<XFailure, T>`.
There is no deprecation for this, since the replacement has the same name as the thing it replaces.

<details>
<summary>The full list</summary>

`fromComponents` on `Email`, `PhoneNumber`, `Iban`, `Bic`, `Isin`, `PaymentCardNumber`, `Isbn` and
`Imei`; `fromBody` on `Issn`, `Isni` and `Gtin`; `GeoCoordinate.from`; `Cidr.from`;
`Hostname.fromLabels`; `DnsName.fromLabels`; `Uuid.fromBytes`; `MacAddress.fromOctets`;
`IpAddress.fromOctets`; `Date.of`; `Date.fromDateTime`.

Two of those keep a nullable sibling, so nothing forces you through the outcome:
`GeoCoordinate.tryFrom` is now derived from `from`, and `tryParse` still sits beside every `parse`.
</details>

Three ways to take one, depending on what the call site wants:

```dart
final outcome = Iban.fromComponents(countryCode: 'GB', bban: bban);

outcome.getOrThrow();                       // assert the parts are good, as 1.x did implicitly
outcome.getOrNull();                        // null on failure
outcome.fold((reason) => log(reason.message), (iban) => send(iban));   // handle both
```

#### `MintedFormatException` becomes `MintedFormatError`

Same rendered message, same typed `failure`, but on the `Error` lineage rather than `Exception`,
because a failure from `getOrThrow` is a bug in the calling source rather than bad input to handle.
It drops `source` and `offset`, which were always null through this path.

**`on FormatException` no longer catches it.** That is deliberate: nothing in the package throws at
input any more, so there is nothing left for a `catch` to do that the return type does not already
force. Rewrite those blocks to fold the outcome instead.

#### Five getters hand back `Digits`

`Isbn.prefix`, `Isbn.body`, `Imei.tac`, `Imei.reportingBodyIdentifier` and `Imei.serialNumber`
return `Digits` rather than `String`. Add `.asString` for the old value, and **watch for
interpolation**: `'$prefix'` now renders `Digits(978)`, and nothing warns you, because interpolation
takes any `Object`.

This is what makes the round trip compile: those parts feed straight back into `fromComponents`,
which has taken `Digits` since 1.0.0.

```dart
Imei.fromComponents(tac: imei.tac, serialNumber: imei.serialNumber);  // 2.0.0, was a type error
```

Nothing else changes shape. `Iban.bban`, `Isin.nsin`, `Email.domain`, `Hostname.labels` and
`IpAddress.octets` all keep the types they have, for reasons recorded in #44.
