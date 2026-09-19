// A validated MAC address is ASCII hex and colons only, so substring slicing is byte-safe.
// ignore_for_file: avoid-substring

import 'dart:typed_data';

import 'package:minted/internal.dart';
import 'package:minted/minted.dart';

import 'failures/mac_address_failure.dart';

/// A MAC address: the 48- or 64-bit address identifying an IEEE 802 network interface, e.g. `00:00:5e:00:53:00`.
/// IEEE Std 802 defines the address itself. [RFC 9542](https://www.rfc-editor.org/rfc/rfc9542) fixes
/// the terminology and reserves the documentation ranges.
///
/// There's no checksum and no reserved value to refuse, so [isMulticast], [isLocallyAdministered] and
/// [isBroadcast] read the bits back rather than gating on them.
///
/// > [!NOTE]
/// > **Not an EUI-48**, and the 64-bit form is not a widened 48-bit one: an address keeps the width
/// > it was parsed at, and the 2 are never equal. Why: `APPENDIX.md#mac-address-value-type`.
///
/// Parsing trims, lower-cases the hex and rewrites the separator to a colon, so the colon, hyphen, Cisco
/// dot-quad (`0000.5e00.5300`) and bare-hex spellings all compare equal. [ieee802] and [bareHex] render
/// 2 of them back. Dot-quad is input-only.
///
/// {@example /example/minted_network_example.dart#mac}
extension type const MacAddress._(String value) {
  /// Parses [input], or `null` unless it's 6 or 8 octets in one notation throughout: colon, hyphen,
  /// Cisco dot-quad, or bare hex.
  static MacAddress? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting [MacAddressMalformed] for an unrecognised notation and [MacAddressWrongOctetCount]
  /// for a recognised one of the wrong width.
  static ParseOutcome<MacAddressFailure, MacAddress> parse(String input) {
    final normalisedInput = input.trim().toLowerCase();
    if (!_notation.hasMatch(normalisedInput)) return const ParseFailure(MacAddressMalformed());

    final strippedHex = normalisedInput.replaceAll(_separators, '');
    final octetCount = strippedHex.length ~/ hexDigitsPerByte;

    return !_octetCounts.contains(octetCount)
        ? ParseFailure(MacAddressWrongOctetCount(octetCount))
        : ParseSuccess(._(_colonSeparated(strippedHex)));
  }

  /// Builds a [MacAddress] from its [octets], reporting [MacAddressWrongOctetCount] unless there are
  /// 6 or 8.
  static ParseOutcome<MacAddressFailure, MacAddress> fromOctets(Uint8List octets) =>
      !_octetCounts.contains(octets.length)
      ? ParseFailure(MacAddressWrongOctetCount(octets.length))
      : parse(hexDigits(octets));

  /// The 6 or 8 raw octets, the inverse of [fromOctets]. What a frame header or a packed column
  /// wants instead of the text.
  Uint8List get octets => hexBytes(bareHex);

  /// How wide this address is: `6` octets for a 48-bit address, `8` for a 64-bit one.
  int get octetCount => octets.length;

  /// The first 3 octets, in the same canonical form, e.g. `00:00:5e`.
  ///
  /// Not named `oui`: those 24 bits are an OUI only under an MA-L assignment, and an MA-M or MA-S address
  /// shares them with other organisations. Why: `APPENDIX.md#mac-address-value-type`.
  String get prefix24 => value.substring(0, _prefix24Length);

  /// Whether this addresses a group of stations rather than one interface: the I/G (individual/group)
  /// bit, commonly called multicast. [isBroadcast] is its all-ones case.
  bool get isMulticast => _firstOctetHas(_individualGroupBit);

  /// Whether this address was administered locally rather than assigned out of an IEEE block: the U/L
  /// (universal/local) bit. [prefix24] identifies nobody for one.
  bool get isLocallyAdministered => _firstOctetHas(_universalLocalBit);

  /// Whether this is [broadcast]. False for the 64-bit all-ones value, which is no such destination.
  bool get isBroadcast => value == broadcast.value;

  /// The IEEE Std 802 hexadecimal representation, `00-00-5E-00-53-00`: hyphen-separated and upper-case,
  /// as the standard writes it and Windows displays it.
  ///
  /// Clause 8.1 reads a colon as the *bit-reversed* representation, so strictly this and [value] are
  /// not 2 spellings of one address. Why the colon form wins anyway: `APPENDIX.md#mac-address-value-type`.
  String get ieee802 => value.toUpperCase().replaceAll(_colon, hyphen);

  /// The separator-free form, `00005e005300`, for a database key or a URL. IEEE sanctions it as a pure
  /// base-16 representation.
  String get bareHex => value.replaceAll(_colon, '');

  /// Orders 2 addresses lexicographically by their canonical form.
  int compareTo(MacAddress other) => value.compareTo(other.value);

  // Both special bits sit in the 1st octet, and a plain mask reads them: transmission order puts the
  // least significant bit of an octet on the wire first, so nothing needs reversing.
  bool _firstOctetHas(int bitMask) =>
      int.parse(value.substring(0, hexDigitsPerByte), radix: hexRadix) & bitMask != 0;

  // IEEE Std 802.3 sentinels.

  /// Names no interface. IEEE Std 802.3 calls it the null address.
  static const allZeros = MacAddress._('00:00:00:00:00:00');

  /// Every station on the link, which [isBroadcast] tests for.
  static const broadcast = MacAddress._('ff:ff:ff:ff:ff:ff');

  // The IANA OUI, 00-00-5E and its 01-00-5E multicast twin, which RFC 9542 §2.1 splits into blocks
  // of 256. Each name is a block's first address, so it is a landmark rather than a membership test.

  /// Reserved, handed out only on IESG ratification.
  static const ianaReserved = MacAddress._('00:00:5e:00:00:00');

  /// The virtual router address, last octet the VRID. RFC 5798 §7.3, IPv4 flavour.
  static const vrrp = MacAddress._('00:00:5e:00:01:00');

  /// Unicast documentation.
  static const ianaDocumentation = MacAddress._('00:00:5e:00:53:00');

  /// Multicast documentation.
  static const ianaDocMulticast = MacAddress._('01:00:5e:90:10:00');

  // IEEE Std 802.1D / 802.1Q group addresses, which bridges consume rather than forward.

  /// Spanning Tree BPDUs, and the nearest customer bridge.
  static const stpBridgeGroup = MacAddress._('01:80:c2:00:00:00');

  /// MAC-specific control, so PAUSE frames.
  static const macControlGroup = MacAddress._('01:80:c2:00:00:01');

  /// Slow Protocols: LACP, link OAM.
  static const slowProtocols = MacAddress._('01:80:c2:00:00:02');

  /// The nearest non-TPMR bridge, which 802.1X PAE and 802.1AE address.
  static const nearestNonTpmr = MacAddress._('01:80:c2:00:00:03');

  /// The provider bridge group.
  static const providerBridge = MacAddress._('01:80:c2:00:00:08');

  /// MVRP, the provider bridge flavour.
  static const providerMvrp = MacAddress._('01:80:c2:00:00:0d');

  /// The nearest bridge, which LLDP and 802.1AS address.
  static const nearestBridge = MacAddress._('01:80:c2:00:00:0e');
}

// The canonical form: the stripped digits re-joined in pairs with a colon.
String _colonSeparated(String hex) => Iterable.generate(
  hex.length ~/ hexDigitsPerByte,
  (octet) => hex.substring(octet * hexDigitsPerByte, (octet + 1) * hexDigitsPerByte),
).join(_colon);

// One anchored alternative per notation, so a spelling that mixes separators matches none. The bare
// form takes digits in pairs, so an odd count fails the shape rather than miscounting.
final _notation = RegExp(
  '^(?:[0-9a-f]{2}(?::[0-9a-f]{2})*' // colon
  '|[0-9a-f]{2}(?:-[0-9a-f]{2})*' // hyphen
  r'|[0-9a-f]{4}(?:\.[0-9a-f]{4})*' // Cisco dot-quad
  r'|(?:[0-9a-f]{2})+)$', // bare hex
);

final _separators = RegExp('[-:.]');

const _colon = ':';
// The 2 widths IEEE 802 addresses come in: 48-bit (Ethernet, Wi-Fi) and 64-bit (802.15.4).
const _octetCounts = {6, 8};
// 3 octets of 2 hex digits, with the 2 colons between them.
const _prefix24Length = 8;
const _individualGroupBit = 0x01;
const _universalLocalBit = 0x02;
