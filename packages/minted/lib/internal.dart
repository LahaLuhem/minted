/// Shared plumbing for the `minted_*` sibling packages. **Not public API**: no semver promise is
/// made about anything here, and a consumer importing it is on their own.
///
/// It exists because Dart privacy is library-scoped, so helpers used by more than one sibling have
/// to be importable to be shared at all. What lives here is exactly what more than one sector
/// needs; a helper with a single sector travels with it (see `AGENTS.md`, repo layout).
///
/// The practical constraint: siblings resolve against any `minted` 3.x, so this is frozen within a
/// major. Additive changes are fine, and a sibling raises its `minted` floor when it starts using
/// one. Breaking changes wait for the next core major.
library;

export 'src/shared/check_digits/luhn_check_digit.dart';
export 'src/shared/encoding/digit_values.dart';
export 'src/shared/encoding/hex_bytes.dart';
export 'src/shared/normalisation/normalisation.dart';
