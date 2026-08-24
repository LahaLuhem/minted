# APPENDIX — `minted_identifiers`

Design rationale for the types this package ships: the "why" behind decisions the code and its
dartdoc alone don't explain. Family-wide rationale (parse-don't-validate, the failure model,
packaging, the shared rules every type leans on) lives in the [workspace APPENDIX][appendix-md];
code style in [CODESTYLE.md][codestyle-md]. Each heading carries an explicit `<a id="…">` anchor;
link by anchor, and keep anchors stable across renames.

<!-- TOC start -->

- [Uuid: a typed identifier, not a generator](#uuid-value-type)
- [Isni: one type, because Orcid would over-promise](#isni-value-type)
- [Isbn: two generations, one value, no hyphens](#isbn-value-type)
- [Issn: the one type that keeps its hyphen](#issn-value-type)
- [Imei: printed in full, unlike a card number](#imei-value-type)
- [Gtin: four lengths, one number, padded to fourteen](#gtin-value-type)

<!-- TOC end -->

---

<a id="uuid-value-type"></a>
## Uuid: a typed identifier, not a generator

A UUID is the textbook `String`-that-should-not-be-a-`String`: 36 characters a caller passes around,
compares, and stores, trusting that whoever produced it wrote a well-formed one. `Uuid` makes
well-formedness a fact of the type, the same bargain [`Email`][parse-dont-validate] and `Iban`
strike.

**It types, it does not generate.** The `uuid` package already mints v1/v4/v7/… UUIDs and does it
well, but it hands back a `String`, so the primitive obsession is untouched the moment the value
leaves the generator. So `uuid` generates, `Uuid` types the result, which also keeps core
dependency-free here (validation is a regex plus two nibble reads). Same shape as
[`Date`][date-value-type] filling the date-only gap: minted adds the missing *value* rather than
re-implementing the neighbouring tool. (Both are named `Uuid`; a consumer using both imports one
with a prefix.)

**An extension type over `String`**, normalised on parse (lower-case hex, strip a `urn:uuid:` prefix
or surrounding `{…}`, trim) so that `Uuid.parse('URN:UUID:F81D…') == Uuid.parse('f81d…')`
([normalise on parse][normalise-on-parse]).

**Accept every well-formed UUID; classify, don't reject.** [Hard rule 3][hard-rules] wants the real
standard rather than a regex shape, but a UUID carries no checksum, and RFC 9562 treats its version
and variant fields as *classification* rather than a validity gate: the Nil and Max UUIDs are valid
with nibbles in "reserved" buckets, and versions `0` and `9`-`15` are reserved-but-legal. Rejecting
on either would refuse values the standard itself calls valid. So `Uuid` validates the grammar and
exposes `version`, `variant`, `isNil` and `isMax` as read-back accessors. Validating the real
standard here *means* parsing those fields correctly, not inventing a stricter rule the RFC does not
have.

<a id="typing-versus-honesty"></a>
**`version` is an `int`; `variant` is an enum**, and the split is the balance this package keeps
returning to: stronger typing against honest representation. The variant is a genuine finite
classification (NCS, RFC 9562, Microsoft, future-reserved), so an enum names its whole domain. The
version is a raw 4-bit field where an enum would either omit the reserved range (and so fail to
represent a valid UUID) or carry a catch-all member that lies about being one value, so an `int` is
the honest type. Resolved per field, on the merits, never as a reflex toward the strongest type.

---

<a id="isni-value-type"></a>
## Isni: one type, because Orcid would over-promise

**There is no `Orcid`, and that is the decision.** ORCID issues iDs from a block inside the ISNI
range, so every ORCID iD *is* an ISNI. Two types need something to tell them apart and the only
candidate is that block: gating on it makes `Isni` refuse most of its own standard, and not gating
makes `Orcid.parse` accept Isaac Newton's ISNI `0000000121032683`. The second is the [`Day`
test][date-value-type], a type named for what it does not guarantee. So one type holds the standard
and `isInOrcidBlock` reports the narrower fact.

The block is genuinely registry-shaped here, unlike [`Isbn`'s prefix](#isbn-value-type): ORCID has
said publicly that it will grow, where ISO 2108's `978`/`979` is fixed. Reporting rather than gating
is [the usual answer][registry-data-ships-a-clock].

**Its check is not the mod-11 the package already had.** ISO 7064 MOD 11-2 doubles a running total,
so its weights are powers of two mod 11 where `mod11_check_character.dart` descends linearly. They
share a modulus and an `X` glyph and agree on nothing: the weighted one rejected all five ORCID iDs
tested against it. Hence a separate file, and a test pinning that the two cannot be swapped, because
that resemblance is exactly what invites a "simplification".

**The block test compares text, not integers.** Sixteen digits reach 10^16, past the web's safe
integer range of 2^53-1, so `int.parse` would lose precision on a real ISNI. Equal-length
zero-padded strings order the same way the numbers do, so `compareTo` is both correct and web-safe.

---

<a id="isbn-value-type"></a>
## Isbn: two generations, one value, no hyphens

ISO 2108 has had two shapes: ten characters with a mod-11 check digit (ten spelled `X`), and, since
2007, thirteen digits with the GS1 mod-10 check. Every 978-prefixed ISBN-13 has exactly one ISBN-10
twin, so the same book arrives written both ways.

**Everything folds to thirteen digits.** Extension-type equality is representation equality, so the
stored form *is* the equality key ([normalise on parse][normalise-on-parse]). Keeping whichever
spelling arrived would make `0-306-40615-2` and `978-0-306-40615-7` unequal and put one book in a
`Set` twice. Nothing is lost, since the mapping is a bijection: `isbn10` rebuilds the legacy form,
`null` for the 979 range that never had one. The check digit is recomputed rather than carried
across, because the two generations use different algorithms.

**979-0 is refused.** `977` is an ISSN and `9790` an ISMN (ISO 10957, printed music): real
identifiers that are also well-formed GS1 article numbers, so a shape-only check would take them for
books. `IsbnInvalidPrefix` names ISMN specifically, because "this is sheet music" is a remedy, while
staying one variant, *not an ISBN*.

**No hyphenation, which is the load-bearing decision.** The groups in `978-0-306-40615-7` are not in
the digits; they come from ISBN International's range table, so embedding a snapshot [ships a
clock][registry-data-ships-a-clock], and a confidently mis-hyphenated ISBN is worse than a plain
one. So `Isbn` strips hyphens and exposes the parts that *are* derivable. `Iban.formatted` is no
precedent: grouping by four needs no table. The `isbn` package on pub carries no range data either,
so it would buy only the two check-digit algorithms, which is the case [hard rule 7][hard-rules]
sends to `lib/src/shared/` rather than a micro-dependency.

**Its blind spot is mod-10's**, so `9780306401657` passes as readily as `9780306406157`; mod-11 over
the ten-digit form catches every transposition. See [check-digit blind
spots][check-digit-blind-spots].

---

<a id="issn-value-type"></a>
## Issn: the one type that keeps its hyphen

**The hyphen is in `value`, where [`Isbn`](#isbn-value-type) strips its own.** That looks
inconsistent and is not, because the two hyphens are different things. An ISBN's groups come from
ISBN International's range table, so rendering them [ships a clock][registry-data-ships-a-clock]; an
ISSN's single hyphen sits after the fourth character always, fixed by ISO 3297 and derivable from
nothing but the length. So there is no data to go stale, the standard's own written form is
`NNNN-NNNC`, and storing anything else would mean `print(issn)` showing a form that appears on no
masthead, in no citation and in no catalogue. `compact` drops it for a URL or a database key, the
same reconstruct-on-demand relationship [`Iban.formatted`][normalise-on-parse] has, just pointing
the other way.

**`checkCharacter` is a `String`, not a `Digit`.** ISO 3297 spells the value ten as `X`, so the
field is not always a digit and the honest type is the wider one. `Isbn.checkDigit` and
`Gtin.checkDigit` *are* `Digit`s, because an ISBN-13 and a GTIN both end in a real digit. The
[typing-versus-honesty balance](#typing-versus-honesty) again, resolved per field.

**Mod-11 has no transposition blind spot**, which makes this the one check-digit type in the package
without a [caveat to pin][check-digit-blind-spots]. The tests pin the opposite: three real ISSNs
with an adjacent pair differing by five, transposed, all rejected. Those are exactly the swaps the
mod-10 family cannot see, so a future "simplification" to mod-10 would turn them green.

**ISSN-L and the 977 barcode are out of scope.** The linking ISSN that ties a title's print and
online numbers together is an assignment held in the ISSN Register, not a computation, and the `977`
EAN-13 that carries an ISSN on a magazine adds two variant digits that are likewise not derivable.
Both are registry lookups wearing a checksum's clothing.

---

<a id="imei-value-type"></a>
## Imei: printed in full, unlike a card number

**It does not mask, and that is the interesting decision.** An IMEI is personal data under GDPR (a
persistent hardware identifier), so the [`PaymentCardNumber`][payment-card-number-value-type]
argument for a masking `toString` looks like it applies. It does not, because the two differ in what
leaking costs. A PAN is an authentication credential: possession is most of what it takes to spend
the money, so a log line is a breach. An IMEI authenticates nothing, is printed on the box, and the
systems that hold one (device inventory, MDM, repair intake, insurance claims) exist to display it.
Redacting by default would fight every caller the type has, who would reach for `value` on each line
and gain nothing. So it stays an `extension type`, free at runtime, and privacy stays where it
belongs: in what the caller logs.

**The TAC is eight digits with no Final Assembly Code beside it.** Pre-2004 IMEIs were TAC (6) + FAC
(2) + serial (6); the 2004 revision folded the FAC into the TAC, and every IMEI issued since is TAC
(8) + serial (6). Since the type has no way to know which era a number came from, and the modern
reading is right for anything currently in circulation, `tac` is the eight-digit field and there is
no `fac` getter. `reportingBodyIdentifier` exposes the two leading digits, which is the one
subdivision of the TAC that has not moved.

**Sixteen digits are named as an IMEISV, not called a miscount.** An IMEISV trades the check digit
for a two-digit software version, so a sixteen-digit input is a real identifier for the same
handset, just not this one. That is the [`Isbn`](#isbn-value-type) courtesy to the ISMN range again:
telling the caller what they actually have beats telling them they cannot count. It is a message
branch on `ImeiWrongLength` rather than its own variant, because the remedy is identical.

**Luhn's blind spots come along**, so `352099001761481` and `352909001761481` both pass; see
[check-digit blind spots][check-digit-blind-spots].

---

<a id="gtin-value-type"></a>
## Gtin: four lengths, one number, padded to fourteen

**Every length folds to GTIN-14, and the padding cannot lie.** GS1's own guidance is to store a GTIN
of any length zero-padded to fourteen digits in one field, and that is exactly what `value` holds,
so a UPC-A and its EAN-13 spelling are one value ([normalise on parse][normalise-on-parse]). The
fold is lossless because GS1 weights from the *right*: the added zeros carry no weight and shift
nobody else's, so the check digit that validated the short form still validates the padded one. That
property is also why the mod-10 had to be lifted out of the ISBN file first, since the old
implementation weighted from the left and so agreed with GS1 only at exactly twelve digits.

**Three getters and a `shortestForm`, because one answer does not fit.** `value` is the storage
form. `shortestForm` is the barcode form, what actually gets printed. The per-length `gtin13`,
`gtin12` and `gtin8` exist because a caller talking to a retail or logistics system needs a
*specific* length, not the shortest one: UPC-A and EAN-13 are not interchangeable at that boundary.
Each is `null` when dropping the leading digits would lose a significant one, so the nullability
answers "does this number fit that length" rather than hiding a truncation.

**No company-prefix / item-reference split.** That boundary comes from GS1's prefix registry rather
than the digits, so it [ships a clock][registry-data-ships-a-clock]. A `Gtin` reports its check
digit and nothing else structural.

**An ISBN-13 parses as a `Gtin`, deliberately.** It is a GTIN-13 in the Bookland prefix range, so
refusing it would be wrong. [`Isbn`](#isbn-value-type) is the narrower type: it additionally pins
the prefix to `978`/`979`, carves out the ISMN range, and rebuilds the ten-digit form. Parse as
whichever one you mean. Both inherit [mod-10's blind spot][check-digit-blind-spots].

[appendix-md]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md
[check-digit-blind-spots]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#check-digit-blind-spots
[codestyle-md]: https://github.com/LahaLuhem/minted/blob/main/CODESTYLE.md
[date-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_chronology/APPENDIX.md#date-value-type
[hard-rules]: https://github.com/LahaLuhem/minted/blob/main/.ai/AGENTS.md#hard-rules
[normalise-on-parse]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#normalise-on-parse
[parse-dont-validate]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#parse-dont-validate
[payment-card-number-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_finance/APPENDIX.md#payment-card-number-value-type
[registry-data-ships-a-clock]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#registry-data-ships-a-clock
