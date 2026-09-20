part of '../geo_bounds.dart';

// The 4 numbers in [input], or null when it holds anything else.
({double west, double south, double east, double north})? _numbersOf(String input) {
  final trimmedInput = input.trim();
  final unwrapped = _bracketed.firstMatch(trimmedInput)?.group(1) ?? trimmedInput;

  return switch (unwrapped.split(_separator).map(double.tryParse).toList()) {
    [final west?, final south?, final east?, final north?] => (
      west: west,
      south: south,
      east: east,
      north: north,
    ),
    _ => null,
  };
}

// One surrounding pair, so a bbox pasted out of GeoJSON parses. dotAll for a pretty-printed array,
// whose newlines double.tryParse then trims.
final _bracketed = RegExp(r'^\[(.*)\]$', dotAll: true);

const _separator = ',';
