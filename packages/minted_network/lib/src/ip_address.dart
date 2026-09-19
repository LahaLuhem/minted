// Every path below runs after the ASCII charset gate, so slicing by index is byte-safe.
// ignore_for_file: avoid-substring

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:ipaddr/ipaddr.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'encoding/octet_bits.dart';
import 'failures/ip_address_failure.dart';

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
  Uint8List get octets => version == IpVersion.v4
      ? .fromList(value.split(_octetSeparator).map(int.parse).toList(growable: false))
      : _octetsOf(IPv6Address(value).toBigInt());

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
  BigInt get _packed =>
      version == .v4 ? .from(IPv4Address(value).toInt()) : IPv6Address(value).toBigInt();

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

/// Which family an [IpAddress] belongs to.
enum IpVersion {
  /// A 32-bit IPv4 address, written as a dotted quad.
  v4,

  /// A 128-bit IPv6 address, written per RFC 5952.
  v6,
}

// minted owns the grammar because the engine's part gates are `int.tryParse`, which lets signs and
// whitespace through. Why: `APPENDIX.md#ip-address-value-type`.
IpAddressFailure? _failureFor(String normalisedInput) => normalisedInput.contains(_hextetSeparator)
    ? _ipv6FailureFor(normalisedInput)
    : _ipv4FailureFor(normalisedInput);

IpAddressFailure? _ipv4FailureFor(String candidate) =>
    _dottedQuad.hasMatch(candidate) ? _dottedFailureFor(candidate) : const IpAddressMalformed();

// Shared by a bare dotted quad and the IPv4 tail of a mapped address, which has the same hazards.
IpAddressFailure? _dottedFailureFor(String dotted) {
  final octets = dotted.split(_octetSeparator);
  final zeroPrefixed = octets.firstWhereOrNull(_hasLeadingZero);
  if (zeroPrefixed != null) return IpAddressLeadingZero(zeroPrefixed);

  // An octet is an unsigned 8-bit field, so Uint8 owns that bound rather than a local copy of 255.
  final outOfRange = octets.firstWhereOrNull((octet) => Uint8.tryFrom(int.parse(octet)) == null);

  return outOfRange != null ? IpAddressPartOutOfRange(outOfRange) : null;
}

IpAddressFailure? _ipv6FailureFor(String candidate) {
  if (!_hexAndSeparators.hasMatch(candidate)) return const IpAddressMalformed();

  final groups = candidate.split(_hextetSeparator);
  final tailFailure = _mappedTailFailureFor(groups.last);
  if (tailFailure != null) return tailFailure;

  final overlong = groups.firstWhereOrNull(
    (group) => !group.contains(_octetSeparator) && group.length > _maxHextetDigits,
  );
  if (overlong != null) return IpAddressPartOutOfRange(overlong);

  // Group count and `::` placement are the engine's job, and all it can still refuse.
  return IPv6Address.tryParse(_hextetOnly(candidate)) == null ? const IpAddressMalformed() : null;
}

IpAddressFailure? _mappedTailFailureFor(String lastGroup) {
  if (!lastGroup.contains(_octetSeparator)) return null;

  return _dottedQuad.hasMatch(lastGroup)
      ? _dottedFailureFor(lastGroup)
      : const IpAddressMalformed();
}

bool _hasLeadingZero(String octet) => octet.length > 1 && octet.startsWith(_zero);

String _canonicalise(String validatedInput) => validatedInput.contains(_hextetSeparator)
    ? _canonicalIpv6(IPv6Address(_hextetOnly(validatedInput)))
    : IPv4Address(validatedInput).toString();

// The engine cannot read the mixed spelling at all, so an IPv4 tail becomes 2 hextets before it
// sees the address. RFC 4291 §2.2 defines the form and dual-stack sockets emit it routinely.
String _hextetOnly(String candidate) {
  final lastSeparator = candidate.lastIndexOf(_hextetSeparator);
  final tail = candidate.substring(lastSeparator + 1);
  if (!tail.contains(_octetSeparator)) return candidate;

  final octets = tail.split(_octetSeparator).map(int.parse).toList();
  final leading = (octets.first << bitsPerOctet) | octets[1];
  final trailing = (octets[2] << bitsPerOctet) | octets[3];

  return '${candidate.substring(0, lastSeparator + 1)}'
      '${leading.toRadixString(hexRadix)}:${trailing.toRadixString(hexRadix)}';
}

// RFC 5952 §5 keeps the mixed spelling on the mapped prefix, which the engine renders as hextets.
// Tested on the value, not the text: `0:0:0:0:ffff:0:0:0` also prints `::ffff:` and is not mapped.
String _canonicalIpv6(IPv6Address address) {
  final packed = address.toBigInt();
  if (packed >> _embeddedV4Bits != _v4MappedPrefix) return address.toString();
  final embedded = (packed & _lowest32Bits).toInt();

  return '$_v4MappedNotation${IPv4Address.tryParseFromInt(embedded)!}';
}

Uint8List _octetsOf(BigInt packed) => .fromList([
  for (var shift = _ipv6Bits - bitsPerOctet; shift >= 0; shift -= bitsPerOctet)
    ((packed >> shift) & _octetMask).toInt(),
]);

BigInt _bigIntOf(Uint8List octets) =>
    octets.fold(BigInt.zero, (packed, octet) => (packed << bitsPerOctet) | BigInt.from(octet));

final _dottedQuad = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
final _hexAndSeparators = RegExp(r'^[0-9a-f:.]+$');
// BigInt has no const constructor, so the IPv6 masks are final rather than const.
final _v4MappedPrefix = BigInt.from(0xffff);
final _lowest32Bits = BigInt.from(0xffffffff);
final _octetMask = BigInt.from(0xff);

const _octetSeparator = '.';
const _hextetSeparator = ':';
const _zero = '0';
const _maxHextetDigits = 4;
const _ipv4OctetCount = 4;
const _ipv6OctetCount = 16;
const _ipv6Bits = 128;
const _embeddedV4Bits = 32;
const _v4MappedNotation = '::ffff:';
const _v6Loopback = '::1';
const _v4LoopbackFirstOctet = 127;
// RFC 1918: 10/8, 172.16/12 and 192.168/16.
const _privateA = 10;
const _privateB = 172;
const _privateBFloor = 16;
const _privateBCeiling = 32;
const _privateC = 192;
const _privateCSecond = 168;
// RFC 4193: fc00::/7, so the top 7 bits of the 1st octet.
const _uniqueLocalMask = 0xfe;
const _uniqueLocalPrefix = 0xfc;
