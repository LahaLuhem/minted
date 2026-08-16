/// Network addresses and names as well-modelled value types.
///
/// Every type is built on "parse, don't validate": build one through `parse`
/// (returning a `ParseOutcome`) or `tryParse` (returning `null`), never a public
/// constructor, so any instance that exists is guaranteed well-formed.
library;

export 'src/cidr.dart';
export 'src/dns_name.dart';
export 'src/failures/cidr_failure.dart';
export 'src/failures/dns_name_failure.dart';
export 'src/failures/hostname_failure.dart';
export 'src/failures/ip_address_failure.dart';
export 'src/failures/mac_address_failure.dart';
export 'src/hostname.dart';
export 'src/ip_address.dart';
export 'src/mac_address.dart';
export 'src/port.dart';
