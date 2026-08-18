/// Constraint types: primitives carrying a constraint, with no standard defining their text form.
///
/// Each declares `tryFrom` and neither parse door, because decimal notation and "one character" are
/// how primitives are written rather than published formats a type could enforce. One invariant each
/// leaves nothing a failure could say that `null` does not, so none carries a failure vocabulary.
///
/// Nothing here depends on `package:minted`: these are the building blocks, not the vocabulary a
/// parse hands back.
library;

export 'src/numerics/digit.dart';
export 'src/numerics/digits.dart';
export 'src/quantities/natural_number.dart';
export 'src/quantities/percentage.dart';
export 'src/quantities/probability.dart';
export 'src/quantities/uint.dart';
export 'src/quantities/uint16.dart';
export 'src/quantities/uint2.dart';
export 'src/quantities/uint32.dart';
export 'src/quantities/uint4.dart';
export 'src/quantities/uint8.dart';
export 'src/text/ascii_alphanumeric.dart';
export 'src/text/ascii_alphanumerics.dart';
export 'src/text/ascii_char.dart';
export 'src/text/ascii_letter.dart';
export 'src/text/ascii_letters.dart';
export 'src/text/char.dart';
export 'src/text/letter.dart';
export 'src/text/letters.dart';
