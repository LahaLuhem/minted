/// Standardised identifiers as well-modelled value types.
///
/// Every type is built on "parse, don't validate": no public constructor, so an instance that exists
/// is well-formed. `parse` reports why it refused, where `tryParse` just hands back `null`.
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
