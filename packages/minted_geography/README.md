[![Pub Version](https://img.shields.io/pub/v/minted_geography.svg)](https://pub.dev/packages/minted_geography)
[![Pub Points](https://img.shields.io/pub/points/minted_geography?logo=dart)](https://pub.dev/packages/minted_geography/score)
[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/LahaLuhem/minted/blob/main/packages/minted_geography/LICENSE)

# minted_geography

Geographic coordinates as well-modelled value types.

Part of the [minted](https://github.com/LahaLuhem/minted) family: pure-Dart value types built on
*parse, don't validate*, so the parser is the only door in and anything that came through it is
well-formed by construction. Once you hold a `GeoCoordinate`, both halves are in range and in the
order you meant.

## Install

```sh
dart pub add minted_geography
```

[`minted`](https://pub.dev/packages/minted) comes with it, holding the shared vocabulary
(`ParseOutcome`, `MintedFailure`, `Digit`, `Digits`, the `Uint` tower). Nothing here drags in
another domain's engine.

## What's in the box

| Type            | What it guarantees                                                          | Standard                                           |
|-----------------|-----------------------------------------------------------------------------|----------------------------------------------------|
| `GeoCoordinate` | a bounded latitude and longitude; all three ISO 6709 widths read as degrees | [ISO 6709](https://en.wikipedia.org/wiki/ISO_6709) |

A swapped latitude and longitude is a type bug no range check catches, so the pair is named at the
boundary. It's a surface coordinate: altitude and a CRS identifier are refused rather than silently
dropped, since their sign, units and datum are all defined by the CRS.

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

// named, so it can't be written swapped:
GeoCoordinate.from(latitude: 48.8577, longitude: 2.295);
```

The runnable version is the
[example](https://github.com/LahaLuhem/minted/blob/main/packages/minted_geography/example/minted_geography_example.dart).

## One shape, every type

- `GeoCoordinate.tryParse(input)` hands back the value, or `null` when the input isn't valid
- `GeoCoordinate.parse(input)` hands back a `ParseOutcome`: the value, or a typed
  `GeoCoordinateFailure` you can `switch` on, or read as a form-field message via `.reasonOrNull`.
  No door throws
- value equality, a canonical `.iso6709` normalised on parse, and `from` for a pair you already hold

The [`minted` README](https://pub.dev/packages/minted) is the family guide: the whole catalogue,
handling failures, and the one caveat (never cast into a minted type).
