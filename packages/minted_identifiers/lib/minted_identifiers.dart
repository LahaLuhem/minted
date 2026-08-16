/// Standardised identifiers as well-modelled value types.
///
/// Every type is built on "parse, don't validate": build one through `parse`
/// (returning a `ParseOutcome`) or `tryParse` (returning `null`), never a public
/// constructor, so any instance that exists is guaranteed well-formed.
library;

export 'src/failures/gtin_failure.dart';
export 'src/failures/imei_failure.dart';
export 'src/failures/isbn_failure.dart';
export 'src/failures/isni_failure.dart';
export 'src/failures/issn_failure.dart';
export 'src/failures/uuid_failure.dart';
export 'src/gtin.dart';
export 'src/imei.dart';
export 'src/isbn.dart';
export 'src/isni.dart';
export 'src/issn.dart';
export 'src/uuid.dart';
