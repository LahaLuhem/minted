import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:ipaddr/ipaddr.dart';
import 'package:meta/meta.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'encoding/octet_bits.dart';
import 'failures/cidr_failure.dart';
import 'failures/ip_address_failure.dart';

part 'cidr.dart';
part 'helpers/cidr_helpers.dart';
part 'helpers/ip_address_helpers.dart';

/// An IP address, v4 or v6, in canonical text form: `192.0.2.1`, `2001:db8::1`.
/// Standards: [RFC 791](https://www.rfc-editor.org/rfc/rfc791) and
/// [RFC 4291](https://www.rfc-editor.org/rfc/rfc4291) for the addresses,
/// [RFC 5952](https://www.rfc-editor.org/rfc/rfc5952) for the canonical IPv6 text.
///
/// Parsing trims, lower-cases and renders v6 per RFC 5952, so `2001:0DB8::0001` and `2001:db8::1` are
/// one value. A leading zero is refused rather than read, being ambiguous between decimal and octal.
///
/// v4 and v6 never compare equal and neither converts to the other. [version] says which you hold. An
/// IPv4-mapped address stays v6 and keeps its `::ffff:192.0.2.1` spelling, which RFC 5952 §5 asks for.
/// Why: `APPENDIX.md#ip-address-value-type`.
///
/// {@example /example/minted_network_example.dart#ipaddress}
extension type const IpAddress._(String value) {
  /// Builds an [IpAddress] from its [octets], 4 for v4 or 16 for v6, reporting [IpAddressWrongOctetCount]
  /// on any other count. The inverse of [octets].
  static ParseOutcome<IpAddressFailure, IpAddress> fromOctets(Uint8List octets) {
    if (octets.length == _ipv4OctetCount) return ParseSuccess(._(octets.join(_octetSeparator)));
    if (octets.length != _ipv6OctetCount) {
      return ParseFailure(IpAddressWrongOctetCount(octets.length));
    }

    return ParseSuccess(._(_canonicalIpv6(.tryParseFromInt(_bigIntOf(octets))!)));
  }

  /// Parses [input], or `null` if it's neither family.
  static IpAddress? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [IpAddressFailure] saying which rule broke.
  static ParseOutcome<IpAddressFailure, IpAddress> parse(String input) {
    final normalisedInput = input.trim().toLowerCase();
    final failure = _failureFor(normalisedInput);

    return failure != null
        ? ParseFailure(failure)
        : ParseSuccess(._(_canonicalise(normalisedInput)));
  }

  /// Which family this address belongs to.
  IpVersion get version => value.contains(_hextetSeparator) ? .v6 : .v4;

  /// The raw octets, 4 for v4 and 16 for v6, the inverse of [fromOctets].
  // Through _hextetOnly, as the parse path goes: a mapped address is stored in the mixed spelling
  // RFC 5952 §5 asks for, and the engine cannot read that back.
  Uint8List get octets => version == IpVersion.v4
      ? .fromList(value.split(_octetSeparator).map(int.parse).toList(growable: false))
      : _octetsOf(IPv6Address(_hextetOnly(value)).toBigInt());

  /// Whether this addresses the host itself: `127.0.0.0/8` for v4, `::1` for v6.
  bool get isLoopback =>
      version == IpVersion.v4 ? octets.first == _v4LoopbackFirstOctet : value == _v6Loopback;

  /// Whether this is in a range kept for private use and never routed on the public internet. RFC 1918
  /// for v4, RFC 4193's `fc00::/7` for v6.
  bool get isPrivate {
    final octets = this.octets;
    if (version == IpVersion.v6) return octets.first & _uniqueLocalMask == _uniqueLocalPrefix;

    return octets.first == _privateA ||
        (octets.first == _privateB &&
            octets[1] >= _privateBFloor &&
            octets[1] < _privateBCeiling) ||
        (octets.first == _privateC && octets[1] == _privateCSecond);
  }

  /// Orders 2 addresses by family first, then numerically within it.
  int compareTo(IpAddress other) {
    final familyOrder = version.index.compareTo(other.version.index);

    return familyOrder != 0 ? familyOrder : _packed.compareTo(other._packed);
  }

  // One number rather than the text, so ordering is numeric: `.10` sorts after `.9`, not before it.
  BigInt get _packed => version == .v4
      ? .from(IPv4Address(value).toInt())
      : IPv6Address(_hextetOnly(value)).toBigInt();

  // Single addresses only. A range is a block, so it belongs on `Cidr`, not here.
  //=================================== UNSPECIFIED & LOOPBACK ===================================//

  /// "This host on this network", and what a socket binds to for every interface. RFC 1122 §3.2.1.3.
  static const unspecifiedV4 = IpAddress._('0.0.0.0');

  /// The v4 loopback, one address out of the whole `127.0.0.0/8` that carries it. RFC 1122 §3.2.1.3.
  static const loopbackV4 = IpAddress._('127.0.0.1');

  /// The v6 spelling of [unspecifiedV4]. RFC 4291 §2.5.2.
  static const unspecifiedV6 = IpAddress._('::');

  /// The v6 loopback, a single address where v4 reserves a whole block. RFC 4291 §2.5.3.
  static const loopbackV6 = IpAddress._('::1');

  //========================================= BROADCAST ==========================================//

  /// Every host on this link, which routers never forward. RFC 919, RFC 922.
  static const limitedBroadcast = IpAddress._('255.255.255.255');
}
