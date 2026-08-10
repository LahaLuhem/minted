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
export 'src/chronology/failures/date_failure.dart';
export 'src/chronology/failures/month_failure.dart';
export 'src/chronology/failures/weekday_failure.dart';
export 'src/chronology/month.dart';
export 'src/chronology/weekday.dart';
export 'src/contact/email.dart';
export 'src/contact/failures/email_failure.dart';
export 'src/contact/failures/phone_number_failure.dart';
export 'src/contact/phone_number.dart';
export 'src/finance/bic.dart';
export 'src/finance/failures/bic_failure.dart';
export 'src/finance/failures/iban_failure.dart';
export 'src/finance/failures/payment_card_number_failure.dart';
export 'src/finance/iban.dart';
export 'src/finance/payment_card_number.dart';
export 'src/identifiers/failures/isbn_failure.dart';
export 'src/identifiers/failures/uuid_failure.dart';
export 'src/identifiers/isbn.dart';
export 'src/identifiers/uuid.dart';
export 'src/numerics/digit.dart';
export 'src/numerics/digits.dart';
export 'src/numerics/failures/digit_failure.dart';
export 'src/numerics/failures/digits_failure.dart';
export 'src/shared/minted_failure.dart';
export 'src/shared/minted_format_exception.dart';
export 'src/shared/parse_outcome.dart';
