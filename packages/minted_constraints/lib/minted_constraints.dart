/// Constraint types: primitives carrying a constraint, with no standard defining their text form.
///
/// Each declares `tryFrom` and neither parse door, because decimal notation and "one character" are
/// how primitives are written rather than published formats a type could enforce. One invariant each
/// leaves nothing a failure could say that `null` does not, so none carries a failure vocabulary.
///
/// Nothing here depends on `package:minted`: these are the building blocks, not the vocabulary a
/// parse hands back.
library;

export 'src/text/ascii_char.dart';
export 'src/text/ascii_letter.dart';
