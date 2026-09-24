part of 'plus_code.dart';

/// A shortened Plus Code: a full one with 2 to 6 leading digits dropped, e.g. `9G8F+6W`.
///
/// It names nowhere on its own. `9G8F+6W` recovers to Zurich next to Zurich and to Sydney next to
/// Sydney, so 2 equal short codes can be 2 places, which is why this is its own type rather than a
/// state of [PlusCode].
///
/// That is also why there is no `bounds` or `centre` here. Go through [recoverNear] first.
extension type const ShortPlusCode._(String value) {
  /// Parses [input], or `null` unless it is a shortened Plus Code.
  static ShortPlusCode? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting [PlusCodeNotShort] when it is a real but full code.
  static ParseOutcome<PlusCodeFailure, ShortPlusCode> parse(String input) {
    final normalisedInput = _normalised(input);
    final failure = _shortFailureFor(normalisedInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalisedInput));
  }

  /// The full code this names when read next to [reference], which is the nearest match rather than
  /// the only one.
  ///
  /// Can't fail. Every short code recovers against every coordinate, both carrying their own
  /// invariants, so there is nothing left for a door to refuse.
  PlusCode recoverNear(GeoCoordinate reference) =>
      PlusCode._(olc.PlusCode.unverified(value).recoverNearest(_latLng(reference)).toString());
}
