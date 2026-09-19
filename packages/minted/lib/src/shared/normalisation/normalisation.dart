/// The patterns, characters and conversions every value type normalises input with, in one place so
/// one type's documented contract ("spaces and hyphens are stripped") can't drift from the next one's.
/// Rationale: `/APPENDIX.md#normalise-on-parse`.
library;

/// Whitespace and hyphens, the separators a standard treats as cosmetic grouping, for a value whose
/// charset excludes both.
final cosmeticSeparators = RegExp(r'[\s-]+');

/// Whitespace alone, for a charset of `A-Z0-9`, where a hyphen is invalid rather than cosmetic.
final whitespace = RegExp(r'\s+');

/// A whole string of nothing but decimal digits.
final digitsOnly = RegExp(r'^\d+$');

/// The hyphen a canonical form puts back after parsing, where the standard fixes its position.
const hyphen = '-';

/// The character a fixed-width field is left-padded with.
const zeroPad = '0';

/// [input] with its cosmetic grouping stripped, for a digits-only charset where upper-casing would do
/// nothing.
String compact(String input) => input.replaceAll(cosmeticSeparators, '');

/// [input] compacted and upper-cased, for a charset that admits letters too.
String compactUpperCase(String input) => compact(input).toUpperCase();

/// [input] with whitespace alone stripped, then upper-cased, for a charset where a hyphen is invalid
/// rather than cosmetic.
String unspacedUpperCase(String input) => input.replaceAll(whitespace, '').toUpperCase();

/// [value] with a negative zero's sign cleared. `-0.0` already equals `0.0` and hashes alike, so it's
/// only the rendered form that needs this.
double positiveZeroed(double value) => value.isNegative && value == 0 ? 0 : value;
