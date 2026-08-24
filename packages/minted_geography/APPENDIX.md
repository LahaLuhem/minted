# APPENDIX — `minted_geography`

Design rationale for the types this package ships: the "why" behind decisions the code and its
dartdoc alone don't explain. Family-wide rationale (parse-don't-validate, the failure model,
packaging, the shared rules every type leans on) lives in the [workspace APPENDIX][appendix-md];
code style in [CODESTYLE.md][codestyle-md]. Each heading carries an explicit `<a id="…">` anchor;
link by anchor, and keep anchors stable across renames.

<!-- TOC start -->

- [GeoCoordinate: a bounded pair, not two doubles](#geo-coordinate-value-type)
- [Geohash: a cell, not a point](#geohash-value-type)
- [GeoBounds: a box that may cross the antimeridian](#geo-bounds-value-type)

<!-- TOC end -->

---

<a id="geo-coordinate-value-type"></a>
## GeoCoordinate: a bounded pair, not two doubles

**The bug this type exists for is a transposition, which no range check can catch.** `f(lat, lng)`
and `f(lng, lat)` have the same signature, and both arguments are plausible degrees. So the pair is
named once, at the parse boundary, and `from` / `tryFrom` take **required named** parameters. That
breaks the habit [`Date`][date-value-type] set with positional `Date(y, m, d)`, deliberately: a
year, a month and a day are not interchangeable at a glance, whereas two degree values are. Half the
transpositions are caught anyway, because a longitude past 90 is not a latitude, which is exactly
the half that would otherwise reach production silently.

**Altitude and a CRS identifier are refused, not modelled and not dropped.**
`+27.5916+086.5640+8850CRSWGS_84/` is valid ISO 6709, and this type rejects it. Modelling altitude
buys no invariant: its sign, its units and its datum are all defined by the CRS, so a `double?
altitude` would be a field the type cannot promise anything about, and validating the CRS needs a
registry we do not carry (see [registry data ships a clock][registry-data-ships-a-clock]). Accepting
the string and discarding the altitude is worse still, because a parse that silently loses part of
its input is not a parse. Refusing says what is true: this type is a surface coordinate.

**The canonical form is decimal degrees even though the input may be sexagesimal.** ISO 6709 uses
the *width* of the degree field as the unit selector — 2/4/6 digits for latitude, 3/5/7 for
longitude — so one point has three spellings. Folding them to one is the same move
[`Gtin`][gtin-value-type] makes with its four lengths. The cost is that a coordinate read from
`+501234-0001042/` renders as `+50.20944444444444-000.17833333333333334/`, which is ugly and exact.
The alternative, rounding to a pretty fixed precision, would break the round-trip the canonical form
promises, so the digits stay. Rendering searches for the shortest fixed-point decimal that reads
back as the same `double` rather than using `toString`, which switches to exponential notation below
`1e-6` — and `1e-7` is a legal latitude but not a legal ISO 6709 field.

**Round-tripping needs both ends exact, and for a while neither was.** The renderer spells at most
20 fraction digits, so anything finer fell back to a truncated spelling: `1e-21` rendered as
`+00.00000000000000000000`, which reads back as zero, and a tiny *negative* degree kept the minus
sign the negative-zero rule below exists to remove. Parsing had the mirror defect, rebuilding a
decimal field by adding the fraction to the degrees, which rounds twice and lands up to one ulp from
converting the field whole, so about one coordinate in four hundred did not survive its own
canonical form. The fixes pair up: `_canonical` snaps every stored degree to one the renderer can
spell exactly (identity above `1e-20`, so identity for anything measurable), and a plain decimal
field now goes through one `double.parse`. The sexagesimal path keeps its base-60 arithmetic, its
digits genuinely needing to be folded, and whatever `double` falls out round-trips like any other.
The snap is also what lets the renderer drop its "no exact spelling" fallback rather than carry an
untestable branch.

**Normalising negative zero is a correctness requirement, not a cosmetic one.** This is the first
floating-point value in the package, which makes two IEEE 754 facts load-bearing that no `int`- or
`String`-backed type had to face. `-0.0 == 0.0` is true while the two need not share a hash code, so
an instance holding `-0.0` would break the Set-and-Map-key guarantee
[normalise on parse][normalise-on-parse] makes. It also happens to be what the standard asks for,
signing the equator and the prime meridian with a plus. `NaN` needs no special case for the same
family of reasons: every comparison with it is false, so a range test written as `>= -bound &&
<= bound` rejects it for free, which is why the check is written positively rather than as
`< -bound || > bound`.

**`-180` folds onto `+180`, and a pole keeps its longitude.** Both are cases where two values name
one place, and they get opposite treatment because only one of them is two spellings of the same
thing. The standard itself says minus denotes "west longitude *or* the 180° meridian", so the
antimeridian has two spellings and one location, and RFC 5870 makes that equality normative for
`geo:` URIs — fold it. At a pole the longitude is *meaningless* rather than redundant, and zeroing
it would discard a number the caller supplied on a guess about what they meant, so it stands.

**Minutes and seconds reaching 60 fail the shape check, not a range check.** The fixed-width scheme
is what makes the grammar unambiguous, and the digit range `00`-`59` is part of that width rather
than a bound on a part, so `+5060+00000/` reports `GeoCoordinateNotIso6709`. This keeps the failure
vocabulary at three variants, one per remedy: fix the format, fix the latitude, fix the longitude.
The same reasoning is why `+46+2/` must be refused rather than read leniently — an unpadded
longitude in a fixed-width format is not a typo the parser can see, it is a *different location*,
and a lenient parser hands back a plausible wrong answer instead of an error.

**A sole member still earns `lib/src/geography/`.** No existing sector fits a coordinate, and the
public API is flat regardless because `minted.dart` re-exports everything, so the folder costs
nothing and is where the next spatial type (Plus Code, MGRS) lands.

---

<a id="geohash-value-type"></a>
## Geohash: a cell, not a point

**The bug is the round trip.** A geohash names a rectangle, and a `String` cannot say whether you
hold the rectangle or a point in it, so code decodes one to a single lat/lng, treats that as *the*
location, and the position moves by up to a cell's width. `bounds` names the cell and `centre` one
point in it, which is the fix. Secondary and more common: `toLowerCase()` is not validation, the
alphabet having dropped `a`, `i`, `l` and `o`.

**No length cap, which is [`Bic`][bic-value-type]'s rule reaching the opposite answer.** Both
*validate what the standard fixes*: ISO 9362 fixes eight or eleven characters, and nothing readable
in CTA-5009-A fixes a ceiling. Twelve is where implementations stop, not where the standard does, so
refusing thirteen would refuse a cell this type represents exactly. `centre` documents where honesty
ends instead: beyond about 23 characters a `double` runs out of mantissa and it stops moving,
measured rather than derived.

**`from` returns its value, not a `ParseOutcome`, the family's first door to do so.** Typing
`precision` as [`NaturalNumber`][constraint-types] makes a bad one unrepresentable rather than
reportable, and with a `GeoCoordinate` opposite it nothing is left to refuse, so an outcome would be
[wrapping a total function][parse-outcome]. That also makes it the first assembly door that can be a
*constructor*, which `prefer_constructors_over_static_methods` demands once the outcome goes. The
cost is real: constraint types expose only `tryFrom`, so call sites read `NaturalNumber.tryFrom(5)!`
and pull in `package:minted`.

**Lossy on purpose, unlike the two rules that forbid loss.**
[`GeoCoordinate`](#geo-coordinate-value-type) refuses altitude and [`Cidr`][cidr-value-type] refuses
host bits, both on "a parse that silently loses input is not a parse". Here `precision` sizes the
loss and `centre` reads it back, so nothing is silent.

**No `compareTo`.** The alphabet is ASCII-ascending on purpose, so plain string order already is
geohash order, which is what makes a prefix range query work. Neighbour and parent traversal are
simply not built yet; the seam problem they solve is real.

**The south-west corner is unreachable through `from`.** `GeoCoordinate` folds `-180` onto `+180`,
so `(-90, -180)` encodes to `pbpbpb`; the all-zero cell parses fine, its centre just inside it.
Pinned by a test, because the fold is right for a coordinate and only surprising if you expected the
grid to have a reachable corner.

---

<a id="geo-bounds-value-type"></a>
## GeoBounds: a box that may cross the antimeridian

**The bug is that `west > east` is legal.** RFC 7946 §5.2 spells a box across the antimeridian by
putting the western edge east of the eastern one, so `170,-45,-170,-35` is Fiji. Range-check it and
you refuse Fiji; skip the check and those four numbers mean either a sliver by the dateline or
nearly its complement, depending on the reader. Downstream is split too, Elasticsearch handling the
crossing where PostGIS does not, so `crossesAntimeridian` is a reported fact and `contains` honours
it.

**The edges are numbers, not two [`GeoCoordinate`](#geo-coordinate-value-type) corners, which is the
one place dogfooding had to stop.** A coordinate folds `-180` onto `+180`, right for a point, where
one meridian has two spellings. An edge is not a point: the whole world is written
`-180,-90,180,90`, and folded corners collapse both longitudes to `180`, turning the commonest bbox
there is into a meridian line. Composition still pays on `contains(GeoCoordinate)` and on the
failure nesting below.

**`Latitude` and `Longitude` are [constraint types][constraint-types] kept here rather than in
`minted_constraints`.** A latitude is a geography concept, not a primitive every sector needs, so
hard rule 2 leaves it with the standard it serves, the same call [`Port`][port-value-type] settled
against sorting by directory. `Longitude` does not fold `-180`, the fold being a *point*
normalisation that stays with `GeoCoordinate`, which is what lets one number type serve both. The
edges then carry their own ranges, leaving `south <= north` as all `from` can refuse and making
`GeoCoordinate.from` the family's second total door.

**Both implement `double`, which is what makes the getters affordable.** Left opaque,
`coordinate.latitude * 2` becomes `.value * 2`, and a box built from a coordinate's parts re-proves
degrees that were already proven. What that buys and costs across the family, and the two types left
opaque anyway, are in [constraint types][constraint-types].

**`parse` still diagnoses, text being where unchecked input arrives.** A constraint type answers
`null` and names nothing, right for a caller who picked that door and wrong for a form field holding
a string. `GeoBoundsInvalidCorner` therefore nests a `GeoCoordinateFailure` just as
[`CidrInvalidAddress`][cidr-value-type] nests an `IpAddressFailure`, over a range diagnosis shared
with `GeoCoordinate.parse`.

**`west == east` is zero width, and a polar cap is not refused because it cannot be written.** The
RFC settles neither. Zero width follows `south == north`, which has to be legal as a horizontal
line, so splitting the axes would be the surprise; the price is spelling the whole world `-180` to
`180`, which it is. The poles need no check: `north: 90` is a box whose top edge is the pole, and a
cap *around* one is not a west/south/east/north rectangle.

[appendix-md]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md
[bic-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_finance/APPENDIX.md#bic-value-type
[cidr-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_network/APPENDIX.md#cidr-value-type
[codestyle-md]: https://github.com/LahaLuhem/minted/blob/main/CODESTYLE.md
[constraint-types]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_constraints/APPENDIX.md#constraint-types
[date-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_chronology/APPENDIX.md#date-value-type
[gtin-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/APPENDIX.md#gtin-value-type
[normalise-on-parse]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#normalise-on-parse
[parse-outcome]: https://github.com/LahaLuhem/minted/blob/main/packages/minted/APPENDIX.md#parse-outcome
[port-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_network/APPENDIX.md#port-value-type
[registry-data-ships-a-clock]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#registry-data-ships-a-clock
