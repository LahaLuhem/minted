/// Network addresses and names as well-modelled value types.
///
/// Every type is built on "parse, don't validate": no public constructor, so an instance that exists
/// is well-formed. `parse` reports why it refused, where `tryParse` just hands back `null`.
library;

export 'src/cidr.dart';
export 'src/dns_name.dart';
export 'src/failures/cidr_failure.dart';
export 'src/failures/dns_name_failure.dart';
export 'src/failures/hostname_failure.dart';
export 'src/failures/ip_address_failure.dart';
export 'src/failures/mac_address_failure.dart';
export 'src/hostname.dart';
// The network addresses behind Cidr's constants. They exist only so those can be `const`, so they
// stay out of the public API. See the banner they sit under in `src/ip_address.dart`.
export 'src/ip_address.dart'
    hide
        docV4_1Network,
        docV4_2Network,
        docV4_3Network,
        docV6Network,
        linkLocalV4Network,
        linkLocalV6Network,
        multicastV4Network,
        multicastV6Network,
        private10Network,
        private172Network,
        private192Network,
        sharedAddressNetwork,
        uniqueLocalV6Network;
export 'src/mac_address.dart';
export 'src/port.dart';
