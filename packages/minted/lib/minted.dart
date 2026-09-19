/// The core of the minted family: the vocabulary every other package speaks.
///
/// `ParseOutcome` is what a fallible door hands back, either the value or a typed `MintedFailure` naming
/// the check it failed. Nothing throws, bar `getOrThrow`, where a caller asserts a value is good instead
/// of branching on it.
///
/// The types themselves live in the sibling packages: `minted_constraints` for the primitives the rest
/// are cut from, then one per domain. Each brings this one along, so depend on the ones you use.
library;

export 'src/shared/outcomes/minted_failure.dart';
export 'src/shared/outcomes/minted_format_error.dart';
export 'src/shared/outcomes/parse_outcome.dart';
