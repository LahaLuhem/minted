/// The patterns, characters and conversions every value type normalises input with, in one place so
/// a type's documented contract ("spaces and hyphens are stripped") cannot drift from four other
/// types'.
///
/// Public within `lib/src/` and never re-exported from `lib/minted.dart`: top-level `_` names are
/// library-private in Dart, so sharing them at all means dropping the underscore. Rationale:
/// `/APPENDIX.md#normalise-on-parse`.
library;

/// Whitespace and hyphens together: the separators a standard treats as cosmetic grouping, in a
/// value whose charset excludes both. Stripped by `Gtin`, `Imei`, `Isbn`, `Issn` and
/// `PaymentCardNumber`.
final cosmeticSeparators = RegExp(r'[\s-]+');

/// Whitespace alone, for a value whose charset is `A-Z0-9` so a hyphen would be invalid rather than
/// cosmetic. Stripped by `Iban` and `Bic`.
final whitespace = RegExp(r'\s+');

/// A whole string of nothing but decimal digits.
final digitsOnly = RegExp(r'^\d+$');

/// The hyphen a canonical form puts back after parsing, where the standard fixes its position.
const hyphen = '-';

/// The character a fixed-width field is left-padded with.
const zeroPad = '0';

/// [input] with its cosmetic grouping stripped. For `Gtin`, `Imei` and `PaymentCardNumber`, whose
/// charsets are digits alone, so case-folding would be a no-op.
String compact(String input) => input.replaceAll(cosmeticSeparators, '');

/// [input] compacted and case-folded, for a charset admitting letters too: `Isbn`, `Isni`, `Issn`.
String compactUpperCase(String input) => compact(input).toUpperCase();

/// [input] with whitespace alone stripped, then case-folded, for a charset where a hyphen is
/// invalid rather than cosmetic: `Bic`, `Iban`, `Isin`.
String unspacedUpperCase(String input) => input.replaceAll(whitespace, '').toUpperCase();

/// [value] with a negative zero's sign cleared, for `GeoCoordinate` and `Percentage`. `-0.0` equals
/// `0.0` and hashes alike, so it is only the rendered form that needs this.
double positiveZeroed(double value) => value.isNegative && value == 0 ? 0 : value;
