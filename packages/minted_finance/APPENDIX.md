# APPENDIX — `minted_finance`

Design rationale for the types this package ships: the "why" behind decisions the code and its
dartdoc alone don't explain. Family-wide rationale (parse-don't-validate, the failure model,
packaging, the shared rules every type leans on) lives in the [workspace APPENDIX][appendix-md];
code style in [CODESTYLE.md][codestyle-md]. Each heading carries an explicit `<a id="…">` anchor;
link by anchor, and keep anchors stable across renames.

<!-- TOC start -->

- [Isin: a prefix that need not be a country](#isin-value-type)
- [Bic: no checksum, so the standard is the whole check](#bic-value-type)
- [PaymentCardNumber: a class so it can mask, and a scheme it only reports](#payment-card-number-value-type)

<!-- TOC end -->

---

<a id="isin-value-type"></a>
## Isin: a prefix that need not be a country

**Luhn, but over an expansion, which changes the weighting.** ISO 6166 replaces every letter with
the two digits of its value (`A`=10 ... `Z`=35) and runs Luhn over the result, so `AU0000XVGZA3`
weighs eighteen characters rather than the twelve it shows. That is why `luhnCheckDigit` had to be
length-agnostic before this type could reuse it, and why the `A`=10 mapping moved out of
`iban_check_digits.dart` into `shared/encoding/`: ISO 13616 folds those values into mod-97 and ISO
6166 spells them out, but the mapping is one convention shared by two standards.

**The prefix is two letters, not a country.** `XS` is Euroclear and Clearstream, `EU` is
supranational, and both are as valid as `GB`. Gating `parse` on ISO 3166 would [ship a
clock][registry-data-ships-a-clock] against the set of non-country prefixes, so `parse` enforces
what the standard actually fixes (two letters) and `hasCountryPrefix` *reports* the narrower fact.
Exactly the [`Bic`](#bic-value-type) split between the standard and the registry.

**Its parts stay `String`.** An NSIN is `[A-Z0-9]`, so the [digits-only rule][typed-digit-subparts]
does not apply and `Digits` there would be a narrower type rather than a stronger one. Same reason
`Iban.fromComponents` keeps its `bban` a `String`.

---

<a id="bic-value-type"></a>
## Bic: no checksum, so the standard is the whole check

ISO 9362 defines no check digit. Every other standardised type here leans on one ([check digits, not
regex][check-digits-not-regex]); `Bic` has nothing to lean on, so what is left is the shape plus one
real lookup: positions 5-6 must be an ISO 3166-1 country. `Bic.parse` will therefore accept a
well-formed code no institution holds, the same honesty [`Uuid`][uuid-value-type] states about its
own lack of a checksum. Naming the gap beats pretending to close it.

**The standard is wider than the registry, so the wider rule wins.** ISO 9362:2014 redefined the
first four characters as alphanumeric, and ISO 20022 retired its letters-only `AnyBICIdentifier`
pattern to follow. SWIFT, as registration authority, still issues letters only. Validating against
current practice would [ship a clock][registry-data-ships-a-clock], so `parse` enforces the standard
and `isSwiftRegistrable` *reports* the narrower shape, which is a fact about the code rather than
grounds to refuse it.

**Eight characters folds to eleven.** A branch code of `XXX` means the primary office, which is
exactly what an eight-character BIC addresses, so the two spellings denote one party and must fold
to compare equal ([normalise on parse][normalise-on-parse]). Folding up rather than down also fixes
the length at eleven, so `branchCode` is never null and `bic8` rebuilds the short form.

**The country list is borrowed, not carried.** `phone_numbers_parser` is already a dependency and
its `IsoCode` has 245 entries, including the `XK` SWIFT uses for Kosovo; it omits only seven
uninhabited territories with no banks. `iban_validator`'s list covers IBAN countries alone and would
reject `CHASUS33`. Borrowing keeps core free of a country table it would have to maintain, at the
cost of a finance type tracking a phone engine's data, which the README states.

**The location code is documented, not modelled.** By SWIFT convention its second character reads
`0` for a test code, `1` for a passive participant, `2` for reverse billing. ISO 9362 assigns none
of those, so an enum naming them would overclaim, and its default case worst of all. Same reasoning
as [`Uuid.version`][uuid-value-type] staying an `int`.

---

<a id="payment-card-number-value-type"></a>
## PaymentCardNumber: a class so it can mask, and a scheme it only reports

**A class, because `toString` must not print the number.** An extension type cannot redeclare it
([extension type vs immutable class][extension-type-representation]), so `'$card'`, a test failure
and a crash-reporter breadcrumb would each carry the whole PAN. So this one is an `@immutable` class
rendering `PaymentCardNumber(••••1111)`, with `value` the single member that hands the number back.
Defence in depth rather than a guarantee, since `value` is one interpolation away and Dart strings
cannot be wiped, but it moves the leak off the default path.

**The scheme is reported, never validated.** ISO/IEC 7812 assigns no brand ranges at all, and the
IIN-to-network table is registry data whose ranges overlap: `65` is claimed by Discover and RuPay,
`55` by Mastercard and Diners US/Canada, `60` by RuPay against Discover's `6011`. Gating `parse` on
it would [ship a clock][registry-data-ships-a-clock], so the table carries only ranges no other
known network contests, and a contested one is left out rather than guessed at: `unknown` means
"cannot say", not "not a card".

Two getters, because one resolution does not fit. `cardScheme` answers the common case;
`cardSchemes` answers the co-brands a single value cannot express, `622126`-`622925` being a
UnionPay that Discover also accepts. `cardScheme` is `cardSchemes.singleOrNull ?? unknown`, so the
two cannot drift and there is one table. `cardSchemesOf` is static because a half-typed number has
no check digit yet and so cannot parse, while a checkout form still wants the brand at the fourth
keystroke.

**Eight digits is the floor, though nothing is issued that short.** ISO/IEC 7812 allows 8 to 19; the
shortest real PAN is a 12-digit Maestro. Enforcing the standard over current practice is the [same
rule][registry-data-ships-a-clock] again, and Luhn already rejects most of what the wider window
admits.

**Luhn's blind spots apply**; see [check-digit blind spots][check-digit-blind-spots].

[appendix-md]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md
[check-digit-blind-spots]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#check-digit-blind-spots
[check-digits-not-regex]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#check-digits-not-regex
[codestyle-md]: https://github.com/LahaLuhem/minted/blob/main/CODESTYLE.md
[extension-type-representation]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#extension-type-representation
[normalise-on-parse]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#normalise-on-parse
[registry-data-ships-a-clock]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#registry-data-ships-a-clock
[typed-digit-subparts]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_constraints/APPENDIX.md#typed-digit-subparts
[uuid-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/APPENDIX.md#uuid-value-type
