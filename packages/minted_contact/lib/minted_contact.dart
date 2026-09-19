/// Email addresses and phone numbers as well-modelled value types.
///
/// Every type is built on "parse, don't validate": no public constructor, so an instance that exists
/// is well-formed. `parse` reports why it refused, where `tryParse` just hands back `null`.
library;

// Re-exported so reading PhoneNumber.type doesn't mean importing the engine as well.
export 'package:phone_numbers_parser/phone_numbers_parser.dart' show PhoneNumberType;

export 'src/email.dart';
export 'src/failures/email_failure.dart';
export 'src/failures/phone_number_failure.dart';
export 'src/phone_number.dart';
