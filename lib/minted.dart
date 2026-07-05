/// Well-modelled value types (domain primitives) for entities usually left as a
/// raw `String`: email, IBAN, and more.
///
/// Every type is built on "parse, don't validate": build it through `tryParse`
/// (returns `null` on invalid input) or `parse` (throws a
/// `MintedFormatException`), never a public constructor, so any instance that
/// exists is guaranteed well-formed.
library;

export 'src/email.dart';
export 'src/iban.dart';
export 'src/shared/minted_format_exception.dart';
