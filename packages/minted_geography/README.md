[![Pub Version](https://img.shields.io/pub/v/minted_geography.svg)](https://pub.dev/packages/minted_geography)
[![Pub Points](https://img.shields.io/pub/points/minted_geography?logo=dart)](https://pub.dev/packages/minted_geography/score)
[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/LahaLuhem/minted/blob/main/packages/minted_geography/LICENSE)

# minted_geography

Coordinates, geohashes and bounding boxes as well-modelled value types.

Part of the [minted](https://github.com/LahaLuhem/minted) family: pure-Dart value types built on
*parse, don't validate*, so the parser is the only door in and anything that came through it is
well-formed by construction. Once you hold a `GeoCoordinate`, both halves are in range and in the
order you meant; once you hold a `Geohash`, it decodes.

## Install

```sh
dart pub add minted_geography
```

[`minted`](https://pub.dev/packages/minted) comes with it, holding the vocabulary a parse hands back
(`ParseOutcome`, `MintedFailure`), and so does
[`minted_constraints`](https://pub.dev/packages/minted_constraints) for the primitives this package's
getters return. Nothing here drags in
another domain's engine.

## What's in the box

| Type            | What it guarantees                                                          | Standard                                                 |
|-----------------|-----------------------------------------------------------------------------|----------------------------------------------------------|
| `GeoCoordinate` | a bounded latitude and longitude; all three ISO 6709 widths read as degrees | [ISO 6709](https://en.wikipedia.org/wiki/ISO_6709)       |
| `Geohash`       | a base32 cell, not a point; the four letters base32 drops are refused       | [CTA-5009-A](https://www.cta.tech/standards/cta-5009-a/) |
| `GeoBounds`     | a box that may cross the antimeridian, which `west <= east` would refuse    | [RFC 7946 §5](https://www.rfc-editor.org/rfc/rfc7946#section-5) |

A swapped latitude and longitude is a type bug no range check catches, so the pair is named at the
boundary. It's a surface coordinate: altitude and a CRS identifier are refused rather than silently
dropped, since their sign, units and datum are all defined by the CRS.

A geohash is a *cell*, not a point, which a `String` cannot say: `bounds` is that cell and `centre`
one point in it. `toLowerCase()` isn't validation either, the alphabet having dropped `a`, `i`, `l`
and `o`.

`west > east` is not a transposition, it is how RFC 7946 §5.2 writes a box across the antimeridian,
so `GeoBounds` reports the crossing and `contains` honours it rather than every caller re-deriving
the case that goes wrong near ±180.

`Latitude` and `Longitude` carry the ranges, so the assembly doors prevent an impossible degree
instead of reporting one: `GeoCoordinate.from` takes them and cannot fail, `tryFrom` takes raw
numbers. Both implement `double`, so reading a degree needs no unwrapping and a box composes
straight out of a coordinate's parts.

## A quick taste

```dart
final eiffel = GeoCoordinate.tryParse('+48.8577+002.295/')!;
eiffel.latitude;     // 48.8577
eiffel.iso6709;      // '+48.8577+002.295/'   (canonical form)
eiffel.sexagesimal;  // '48°51′27.72″N 2°17′42″E'   (display form)

// ISO 6709 selects the unit by field width, and all three widths fold to degrees, so the same
// point spelled as degrees-minutes-seconds is the same value:
GeoCoordinate.tryParse('+485127.72+0021742/') == eiffel;   // true
GeoCoordinate.tryParse('+5012-00010/')!.latitude;          // 50.2   (degrees and minutes)

GeoCoordinate.tryParse('+46+2/');   // null: an unpadded longitude is a different location

// named and typed, so it can't be written swapped. from cannot fail, tryFrom takes raw numbers:
GeoCoordinate.from(latitude: Latitude.tryFrom(48.8577)!, longitude: Longitude.tryFrom(2.295)!);
GeoCoordinate.tryFrom(latitude: 48.8577, longitude: 2.295);

// Geohash: from takes a coordinate and cannot fail, so it hands back the value, not an outcome.
final cell = Geohash.from(coordinate: eiffel, precision: NaturalNumber.tryFrom(5)!);
cell.value;            // 'u09tu'   (canonical form: trimmed, lower-cased)
cell.centre.iso6709;   // '+48.84521484375+002.30712890625/'   inside the cell, not the tower
cell.bounds.bbox;      // '2.28515625,48.8232421875,2.3291015625,48.8671875'   the cell itself

Geohash.tryParse('EZS42 ') == Geohash.tryParse('ezs42');   // true: case and padding fold away
Geohash.tryParse('ezsa2');   // null: 'a' is not in the geohash alphabet
['ezs42', 'ezs41', 'u4pruy']..sort();   // spatial order free: the alphabet is ASCII-ascending

// GeoBounds: west past east is a crossing, not a transposition.
final fiji = GeoBounds.tryParse('170,-45,-170,-35')!;
fiji.crossesAntimeridian;                                              // true
fiji.contains(GeoCoordinate.tryFrom(latitude: -40, longitude: 179)!);  // true
fiji.contains(GeoCoordinate.tryFrom(latitude: -40, longitude: 0)!);    // false, the long way round
GeoBounds.tryParse('[-180, -90, 180, 90]')?.bbox;   // '-180.0,-90.0,180.0,90.0'   the whole world
```

The runnable version is the
[example](https://github.com/LahaLuhem/minted/blob/main/packages/minted_geography/example/minted_geography_example.dart).

## One shape, every type

- `GeoCoordinate.tryParse(input)` hands back the value, or `null` when the input isn't valid
- `GeoCoordinate.parse(input)` hands back a `ParseOutcome`: the value, or a typed
  `GeoCoordinateFailure` you can `switch` on, or read as a form-field message via `.reasonOrNull`.
  No door throws
- value equality, a canonical form normalised on parse (`.iso6709`, `Geohash.value`), and `from` for
  parts you already hold, which for `Geohash` returns the value rather than an outcome

The [`minted` README](https://pub.dev/packages/minted) is the family guide: the package index,
handling failures, and the one caveat (never cast into a minted type).
