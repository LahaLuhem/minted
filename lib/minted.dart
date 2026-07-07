/// Well-modelled value types (domain primitives) for entities usually left as a
/// raw `String`: email, IBAN, and more.
///
/// Every type is built on "parse, don't validate": build it through `tryParse`
/// (returns `null` on invalid input) or `parse` (throws a
/// `MintedFormatException`), never a public constructor, so any instance that
/// exists is guaranteed well-formed.
library;

// PhoneNumber.type returns this; re-exported so consumers need not import the
// underlying engine.
export 'package:phone_numbers_parser/phone_numbers_parser.dart' show PhoneNumberType;

export 'src/chronology/date.dart';
export 'src/chronology/month.dart';
export 'src/contact/email.dart';
export 'src/contact/phone_number.dart';
export 'src/finance/iban.dart';
export 'src/identifiers/uuid.dart';
export 'src/numerics/digit.dart';
export 'src/numerics/digits.dart';
export 'src/shared/minted_format_exception.dart';
