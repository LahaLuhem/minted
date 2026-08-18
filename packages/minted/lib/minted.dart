/// The core of the minted family: the vocabulary every domain package speaks, plus the numeric
/// primitives they build on.
///
/// `ParseOutcome`, `MintedFailure` and `MintedFormatError` are what a parse hands back anywhere in
/// the family. `Digit`, `Digits`, the `Uint` tower, `NaturalNumber`, `Percentage` and `Probability`
/// are values in their own right and the building blocks the domain types use.
///
/// Every type is built on "parse, don't validate": build it through `parse` (returns a
/// `ParseOutcome`, the value or a typed failure) or `tryParse` (returns `null`), never a public
/// constructor, so any instance that exists is guaranteed well-formed. No door throws; `getOrThrow`
/// on an outcome is the caller opting in.
///
/// The domain types live beside this package: `minted_chronology`, `minted_contact`,
/// `minted_finance`, `minted_geography`, `minted_identifiers` and `minted_network`. Depend on the
/// ones you use; this package comes with each of them.
library;

export 'src/quantities/natural_number.dart';
export 'src/quantities/percentage.dart';
export 'src/quantities/probability.dart';
export 'src/quantities/uint.dart';
export 'src/quantities/uint16.dart';
export 'src/quantities/uint2.dart';
export 'src/quantities/uint32.dart';
export 'src/quantities/uint4.dart';
export 'src/quantities/uint8.dart';
export 'src/shared/outcomes/minted_failure.dart';
export 'src/shared/outcomes/minted_format_error.dart';
export 'src/shared/outcomes/parse_outcome.dart';
