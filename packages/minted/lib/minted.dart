/// Well-modelled value types (domain primitives) for entities usually left as a
/// raw `String`: email, IBAN, and more.
///
/// Every type is built on "parse, don't validate": build it through `parse` (returns a
/// `ParseOutcome`, the value or a typed failure) or `tryParse` (returns `null`), never a public
/// constructor, so any instance that exists is guaranteed well-formed. No door throws; `getOrThrow`
/// on an outcome is the caller opting in.
library;

// PhoneNumber.type returns this; re-exported so consumers need not import the
// underlying engine.
export 'package:phone_numbers_parser/phone_numbers_parser.dart' show PhoneNumberType;

export 'src/chronology/date.dart';
export 'src/chronology/failures/date_failure.dart';
export 'src/chronology/failures/iso8601_duration_failure.dart';
export 'src/chronology/failures/month_failure.dart';
export 'src/chronology/iso8601_duration.dart';
export 'src/chronology/month.dart';
export 'src/chronology/weekday.dart';
export 'src/commerce/failures/gtin_failure.dart';
export 'src/commerce/gtin.dart';
export 'src/contact/email.dart';
export 'src/contact/failures/email_failure.dart';
export 'src/contact/failures/phone_number_failure.dart';
export 'src/contact/phone_number.dart';
export 'src/finance/bic.dart';
export 'src/finance/failures/bic_failure.dart';
export 'src/finance/failures/iban_failure.dart';
export 'src/finance/failures/isin_failure.dart';
export 'src/finance/failures/payment_card_number_failure.dart';
export 'src/finance/iban.dart';
export 'src/finance/isin.dart';
export 'src/finance/payment_card_number.dart';
export 'src/geography/failures/geo_coordinate_failure.dart';
export 'src/geography/geo_coordinate.dart';
export 'src/identifiers/failures/imei_failure.dart';
export 'src/identifiers/failures/isbn_failure.dart';
export 'src/identifiers/failures/isni_failure.dart';
export 'src/identifiers/failures/issn_failure.dart';
export 'src/identifiers/failures/uuid_failure.dart';
export 'src/identifiers/imei.dart';
export 'src/identifiers/isbn.dart';
export 'src/identifiers/isni.dart';
export 'src/identifiers/issn.dart';
export 'src/identifiers/uuid.dart';
export 'src/network/cidr.dart';
export 'src/network/dns_name.dart';
export 'src/network/failures/cidr_failure.dart';
export 'src/network/failures/dns_name_failure.dart';
export 'src/network/failures/hostname_failure.dart';
export 'src/network/failures/ip_address_failure.dart';
export 'src/network/failures/mac_address_failure.dart';
export 'src/network/hostname.dart';
export 'src/network/ip_address.dart';
export 'src/network/mac_address.dart';
export 'src/network/port.dart';
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
export 'src/shared/outcomes/minted_failure.dart';
export 'src/shared/outcomes/minted_format_error.dart';
export 'src/shared/outcomes/parse_outcome.dart';
