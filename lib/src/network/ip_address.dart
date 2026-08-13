// Every path below runs after the ASCII charset gate, so slicing by index is byte-safe.
// ignore_for_file: avoid-substring

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:ipaddr/ipaddr.dart';

import '../quantities/uint8.dart';
import '../shared/encoding/hex_bytes.dart';
import '../shared/encoding/octet_bits.dart';
import '../shared/outcomes/minted_format_exception.dart';
import '../shared/outcomes/parse_outcome.dart';
import 'failures/ip_address_failure.dart';

/// An IP address, v4 or v6, in canonical text form: `192.0.2.1`, `2001:db8::1`.
/// Standards: [RFC 791](https://www.rfc-editor.org/rfc/rfc791) and
/// [RFC 4291](https://www.rfc-editor.org/rfc/rfc4291) for the addresses,
/// [RFC 5952](https://www.rfc-editor.org/rfc/rfc5952) for the canonical IPv6 text.
///
/// Parse, don't validate: `2001:0DB8::0001` and `2001:db8::1` are one address that a `String`
/// compares as two, and `InternetAddress` cannot help, being `dart:io` and so absent on the web.
/// A leading zero is refused rather than read, since it is ambiguous between decimal and octal.
///
/// A v4 and a v6 address are never equal, and neither is converted to the other; [version] reports
/// which one you hold. An IPv4-mapped address stays v6 and keeps its mixed spelling,
/// `::ffff:192.0.2.1`, which RFC 5952 §5 asks for on that prefix.
/// Why: `APPENDIX.md#ip-address-value-type`.
///
/// Normalisation on parse: trimmed, lower-cased, and rendered per RFC 5952 for v6, so leading zeros
/// go, `::` takes the longest zero run, and a single zero field is never compressed.
///
/// {@example /example/minted_example.dart#ipaddress}
extension type const IpAddress._(String value) {
  /// Builds an [IpAddress] from its [octets], 4 for v4 or 16 for v6, throwing
  /// [MintedFormatException] on any other count. The inverse of [octets].
  static IpAddress fromOctets(Uint8List octets) {
    if (octets.length == _ipv4OctetCount) return ._(octets.join(_octetSeparator));
    if (octets.length != _ipv6OctetCount) {
      throw MintedFormatException.from(IpAddressWrongOctetCount(octets.length), '$octets');
    }

    return ._(_canonicalIpv6(.tryParseFromInt(_bigIntOf(octets))!));
  }

  /// Parses [input] as an IP address, or returns `null` when it is neither family.
  /// See the type docs for the normalisation applied.
  static IpAddress? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an IP address, reporting the [IpAddressFailure] saying which rule broke.
  static ParseOutcome<IpAddressFailure, IpAddress> parse(String input) {
    final normalisedInput = input.trim().toLowerCase();
    final failure = _failureFor(normalisedInput);

    return failure != null
        ? ParseFailure(failure)
        : ParseSuccess(._(_canonicalise(normalisedInput)));
  }

  /// Which family this address belongs to. The two never compare equal, whatever they spell.
  IpVersion get version => value.contains(_hextetSeparator) ? .v6 : .v4;

  /// The raw octets, 4 for v4 and 16 for v6, the inverse of [fromOctets].
  Uint8List get octets => version == IpVersion.v4
      ? .fromList(value.split(_octetSeparator).map(int.parse).toList(growable: false))
      : _octetsOf(IPv6Address(value).toBigInt());

  /// Whether this addresses the host itself: `127.0.0.0/8` for v4, `::1` for v6.
  bool get isLoopback =>
      version == IpVersion.v4 ? octets.first == _v4LoopbackFirstOctet : value == _v6Loopback;

  /// Whether this is from a range reserved for private use and never routed on the public internet:
  /// RFC 1918 for v4, RFC 4193's `fc00::/7` unique local addresses for v6.
  bool get isPrivate {
    final octets = this.octets;
    if (version == IpVersion.v6) return octets.first & _uniqueLocalMask == _uniqueLocalPrefix;

    return octets.first == _privateA ||
        (octets.first == _privateB &&
            octets[1] >= _privateBFloor &&
            octets[1] < _privateBCeiling) ||
        (octets.first == _privateC && octets[1] == _privateCSecond);
  }

  /// Orders two addresses by family first, then numerically within it. Extension types cannot
  /// implement `Comparable<IpAddress>`, so this is a plain method, not the [Comparable] interface.
  int compareTo(IpAddress other) {
    final familyOrder = version.index.compareTo(other.version.index);

    return familyOrder != 0 ? familyOrder : _packed.compareTo(other._packed);
  }

  // One number rather than the text, so ordering is numeric: `.10` sorts after `.9`, not before it.
  BigInt get _packed =>
      version == .v4 ? .from(IPv4Address(value).toInt()) : IPv6Address(value).toBigInt();

  // The engine parses structure and renders RFC 5952; minted owns the grammar, because the
  // engine's part gates are `int.tryParse`, which admits signs and whitespace.
  // Why: `APPENDIX.md#ip-address-value-type`.
  static IpAddressFailure? _failureFor(String normalisedInput) =>
      normalisedInput.contains(_hextetSeparator)
      ? _ipv6FailureFor(normalisedInput)
      : _ipv4FailureFor(normalisedInput);

  static IpAddressFailure? _ipv4FailureFor(String candidate) =>
      _dottedQuad.hasMatch(candidate) ? _dottedFailureFor(candidate) : const IpAddressMalformed();

  // Shared by a bare dotted quad and the IPv4 tail of a mapped address, which has the same hazards.
  static IpAddressFailure? _dottedFailureFor(String dotted) {
    final octets = dotted.split(_octetSeparator);
    final zeroPrefixed = octets.firstWhereOrNull(_hasLeadingZero);
    if (zeroPrefixed != null) return IpAddressLeadingZero(zeroPrefixed);

    // An octet is an unsigned 8-bit field, so Uint8 owns that bound rather than a local copy of 255.
    final outOfRange = octets.firstWhereOrNull((octet) => Uint8.tryFrom(int.parse(octet)) == null);

    return outOfRange != null ? IpAddressPartOutOfRange(outOfRange) : null;
  }

  static IpAddressFailure? _ipv6FailureFor(String candidate) {
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

  static IpAddressFailure? _mappedTailFailureFor(String lastGroup) {
    if (!lastGroup.contains(_octetSeparator)) return null;

    return _dottedQuad.hasMatch(lastGroup)
        ? _dottedFailureFor(lastGroup)
        : const IpAddressMalformed();
  }

  static bool _hasLeadingZero(String octet) => octet.length > 1 && octet.startsWith(_zero);

  static String _canonicalise(String validatedInput) => validatedInput.contains(_hextetSeparator)
      ? _canonicalIpv6(IPv6Address(_hextetOnly(validatedInput)))
      : IPv4Address(validatedInput).toString();

  // The engine cannot read the mixed spelling at all, so an IPv4 tail becomes two hextets before it
  // sees the address. RFC 4291 §2.2 defines the form and dual-stack sockets emit it routinely.
  static String _hextetOnly(String candidate) {
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
  static String _canonicalIpv6(IPv6Address address) {
    final packed = address.toBigInt();
    if (packed >> _embeddedV4Bits != _v4MappedPrefix) return address.toString();
    final embedded = (packed & _lowest32Bits).toInt();

    return '$_v4MappedNotation${IPv4Address.tryParseFromInt(embedded)!}';
  }

  static Uint8List _octetsOf(BigInt packed) => .fromList([
    for (var shift = _ipv6Bits - bitsPerOctet; shift >= 0; shift -= bitsPerOctet)
      ((packed >> shift) & _octetMask).toInt(),
  ]);

  static BigInt _bigIntOf(Uint8List octets) =>
      octets.fold(BigInt.zero, (packed, octet) => (packed << bitsPerOctet) | BigInt.from(octet));

  static final _dottedQuad = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
  static final _hexAndSeparators = RegExp(r'^[0-9a-f:.]+$');
  // BigInt has no const constructor, so the IPv6 masks are final rather than const.
  static final _v4MappedPrefix = BigInt.from(0xffff);
  static final _lowest32Bits = BigInt.from(0xffffffff);
  static final _octetMask = BigInt.from(0xff);

  static const _octetSeparator = '.';
  static const _hextetSeparator = ':';
  static const _zero = '0';
  static const _maxHextetDigits = 4;
  static const _ipv4OctetCount = 4;
  static const _ipv6OctetCount = 16;
  static const _ipv6Bits = 128;
  static const _embeddedV4Bits = 32;
  static const _v4MappedNotation = '::ffff:';
  static const _v6Loopback = '::1';
  static const _v4LoopbackFirstOctet = 127;
  // RFC 1918: 10/8, 172.16/12 and 192.168/16.
  static const _privateA = 10;
  static const _privateB = 172;
  static const _privateBFloor = 16;
  static const _privateBCeiling = 32;
  static const _privateC = 192;
  static const _privateCSecond = 168;
  // RFC 4193: fc00::/7, so the top seven bits of the first octet.
  static const _uniqueLocalMask = 0xfe;
  static const _uniqueLocalPrefix = 0xfc;
}

/// Which family an [IpAddress] belongs to. Derived from an address that already parsed, so it is a
/// classification rather than a value type: no parse door of its own.
enum IpVersion {
  /// A 32-bit IPv4 address, written as a dotted quad.
  v4,

  /// A 128-bit IPv6 address, written per RFC 5952.
  v6,
}
