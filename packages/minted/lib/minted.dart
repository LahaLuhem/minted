/// The core of the minted family: the vocabulary every other package speaks.
///
/// `ParseOutcome` is what a fallible door hands back, either the value or a typed `MintedFailure`
/// naming the check it failed. No door throws. `MintedFormatError` is raised only by `getOrThrow`,
/// where a caller asserts a value is good instead of branching on it.
///
/// The types themselves live beside this package. `minted_constraints` holds the primitives the
/// rest are cut from, and `minted_chronology`, `minted_contact`, `minted_finance`,
/// `minted_geography`, `minted_identifiers` and `minted_network` hold the domain types. Each brings
/// this package with it, so depend on the ones you use.
library;

export 'src/shared/outcomes/minted_failure.dart';
export 'src/shared/outcomes/minted_format_error.dart';
export 'src/shared/outcomes/parse_outcome.dart';
