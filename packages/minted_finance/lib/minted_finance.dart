/// IBANs, BICs, ISINs and payment card numbers as well-modelled value types.
///
/// Every type is built on "parse, don't validate": build one through `parse`
/// (returning a `ParseOutcome`) or `tryParse` (returning `null`), never a public
/// constructor, so any instance that exists is guaranteed well-formed.
library;

export 'src/bic.dart';
export 'src/failures/bic_failure.dart';
export 'src/failures/iban_failure.dart';
export 'src/failures/isin_failure.dart';
export 'src/failures/payment_card_number_failure.dart';
export 'src/iban.dart';
export 'src/isin.dart';
export 'src/payment_card_number.dart';
