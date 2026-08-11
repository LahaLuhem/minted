/// The patterns and characters every value type normalises input with, in one place so a type's
/// documented contract ("spaces and hyphens are stripped") cannot drift from four other types'.
///
/// Public within `lib/src/` and never re-exported from `lib/minted.dart`: top-level `_` names are
/// library-private in Dart, so sharing them at all means dropping the underscore. Rationale:
/// `APPENDIX.md#normalise-on-parse`.
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
