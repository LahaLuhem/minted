/// Email addresses and phone numbers as well-modelled value types.
///
/// Every type is built on "parse, don't validate": build one through `parse`
/// (returning a `ParseOutcome`) or `tryParse` (returning `null`), never a public
/// constructor, so any instance that exists is guaranteed well-formed.
library;

// PhoneNumber.type returns this; re-exported so consumers need not import the
// underlying engine.
export 'package:phone_numbers_parser/phone_numbers_parser.dart' show PhoneNumberType;

export 'src/email.dart';
export 'src/failures/email_failure.dart';
export 'src/failures/phone_number_failure.dart';
export 'src/phone_number.dart';
