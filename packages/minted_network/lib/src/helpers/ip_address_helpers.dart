// A const cannot be `late`, so the rule below has nothing to offer the network addresses.
// ignore_for_file: use_late_for_private_fields_and_variables
// Named for the part it holds rather than for IpVersion, the first type in it.
// ignore_for_file: prefer-match-file-name
// Every path here runs after the ASCII charset gate, so slicing by index is byte-safe.
// ignore_for_file: avoid-substring

part of '../ip_address.dart';

/// Which family an [IpAddress] belongs to.
enum IpVersion() {
  /// A 32-bit IPv4 address, written as a dotted quad.
  v4,

  /// A 128-bit IPv6 address, written per RFC 5952.
  v6,
}

//==================================== CIDR NETWORK ADDRESSES ====================================//
// A const `Cidr` needs a const [IpAddress], and only this library can mint one. Private rather than
// members of [IpAddress], because nobody wants `10.0.0.0` on its own.

/// The network address of `10.0.0.0/8`.
const _private10Network = IpAddress._('10.0.0.0');

/// The network address of `172.16.0.0/12`.
const _private172Network = IpAddress._('172.16.0.0');

/// The network address of `192.168.0.0/16`.
const _private192Network = IpAddress._('192.168.0.0');

/// The network address of `fc00::/7`.
const _uniqueLocalV6Network = IpAddress._('fc00::');

/// The network address of `100.64.0.0/10`.
const _sharedAddressNetwork = IpAddress._('100.64.0.0');

/// The network address of `169.254.0.0/16`.
const _linkLocalV4Network = IpAddress._('169.254.0.0');

/// The network address of `fe80::/10`.
const _linkLocalV6Network = IpAddress._('fe80::');

/// The network address of `224.0.0.0/4`.
const _multicastV4Network = IpAddress._('224.0.0.0');

/// The network address of `ff00::/8`.
const _multicastV6Network = IpAddress._('ff00::');

/// The network address of `192.0.2.0/24`.
const _docV4_1Network = IpAddress._('192.0.2.0');

/// The network address of `198.51.100.0/24`.
const _docV4_2Network = IpAddress._('198.51.100.0');

/// The network address of `203.0.113.0/24`.
const _docV4_3Network = IpAddress._('203.0.113.0');

/// The network address of `2001:db8::/32`.
const _docV6Network = IpAddress._('2001:db8::');

/// The network address of `::ffff:0.0.0.0/96`, in the mixed spelling parse renders it as.
const _v4MappedV6Network = IpAddress._('::ffff:0.0.0.0');

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
