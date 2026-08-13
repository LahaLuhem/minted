// A validated MAC address is ASCII hex and colons only, so substring slicing is byte-safe.
// ignore_for_file: avoid-substring

import 'dart:typed_data';

import '../shared/encoding/hex_bytes.dart';
import '../shared/normalisation/normalisation.dart';
import '../shared/outcomes/minted_format_exception.dart';
import '../shared/outcomes/parse_outcome.dart';
import 'failures/mac_address_failure.dart';

/// A MAC address: the 48- or 64-bit address identifying an IEEE 802 network interface, e.g.
/// `00:00:5e:00:53:00`. IEEE Std 802 defines the address itself;
/// [RFC 9542](https://www.rfc-editor.org/rfc/rfc9542) fixes the terminology and reserves the
/// documentation ranges.
///
/// Parse, don't validate: a [MacAddress] exists only if it is well-formed. There is no checksum
/// and no reserved value to refuse, so [isMulticast], [isLocallyAdministered] and [isBroadcast]
/// read the bits back rather than gating on them.
///
/// > [!NOTE]
/// > **Not an EUI-48**, which the IEEE reserves for an individual, universally-administered
/// > address. Nor is the 64-bit form a widened 48-bit one: mapping between the widths is
/// > deprecated, so an address keeps the width it was parsed at, and the two are never equal.
/// > Why: `APPENDIX.md#mac-address-value-type`.
///
/// Normalisation on parse: whitespace trimmed, hex lower-cased, separator rewritten to a colon, so
/// the colon, hyphen, Cisco dot-quad (`0000.5e00.5300`) and bare-hex spellings of one address all
/// compare equal. [ieee802] and [bareHex] render two of them back; dot-quad is input-only.
///
/// {@example /example/minted_example.dart#mac}
extension type const MacAddress._(String value) {
  /// Parses [input] as a MAC address, or returns `null` unless it is six or eight octets in one
  /// notation throughout: colon, hyphen, Cisco dot-quad, or bare hex.
  static MacAddress? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a MAC address, reporting [MacAddressMalformed] for an unrecognised notation
  /// and [MacAddressWrongOctetCount] for a recognised one of the wrong width.
  static ParseOutcome<MacAddressFailure, MacAddress> parse(String input) {
    final normalisedInput = input.trim().toLowerCase();
    if (!_notation.hasMatch(normalisedInput)) return const ParseFailure(MacAddressMalformed());

    final strippedHex = normalisedInput.replaceAll(_separators, '');
    final octetCount = strippedHex.length ~/ hexDigitsPerByte;

    return !_octetCounts.contains(octetCount)
        ? ParseFailure(MacAddressWrongOctetCount(octetCount))
        : ParseSuccess(._(_colonSeparated(strippedHex)));
  }

  /// Builds a [MacAddress] from its [octets], throwing [MintedFormatException] unless there are six
  /// or eight. Every sequence of either length is valid, so the count is all it rejects.
  static MacAddress fromOctets(Uint8List octets) => !_octetCounts.contains(octets.length)
      ? throw MintedFormatException.from(MacAddressWrongOctetCount(octets.length), '$octets')
      : tryParse(hexDigits(octets))!;

  /// The six or eight raw octets, the inverse of [fromOctets]. For binary interop (a frame header,
  /// a packed database column) where the text form would waste space.
  Uint8List get octets => hexBytes(bareHex);

  /// How wide this address is: `6` octets for a 48-bit address, `8` for a 64-bit one.
  int get octetCount => octets.length;

  /// The first three octets, in the same canonical form, e.g. `00:00:5e`.
  ///
  /// Not named `oui`: those 24 bits are an OUI only under an MA-L assignment, and an MA-M or MA-S
  /// address shares them with other organisations. Why: `APPENDIX.md#mac-address-value-type`.
  String get prefix24 => value.substring(0, _prefix24Length);

  /// Whether this addresses a group of stations rather than one interface: the I/G
  /// (individual/group) bit, commonly called multicast. [isBroadcast] is its all-ones case.
  bool get isMulticast => _firstOctetHas(_individualGroupBit);

  /// Whether this address was administered locally rather than assigned out of an IEEE block: the
  /// U/L (universal/local) bit. [prefix24] identifies nobody for one.
  bool get isLocallyAdministered => _firstOctetHas(_universalLocalBit);

  /// Whether this is the broadcast address, `ff:ff:ff:ff:ff:ff`, which IEEE 802.3 delivers to every
  /// station on the segment. False for the 64-bit all-ones value, which is no such destination.
  bool get isBroadcast => value == _broadcast;

  /// The IEEE Std 802 hexadecimal representation, `00-00-5E-00-53-00`: hyphen-separated and
  /// upper-case, as the standard writes it and Windows displays it.
  ///
  /// Clause 8.1 reads a colon as the *bit-reversed* representation, so strictly this and [value]
  /// are not two spellings of one address. Why the colon form wins anyway:
  /// `APPENDIX.md#mac-address-value-type`.
  String get ieee802 => value.toUpperCase().replaceAll(_colon, hyphen);

  /// The separator-free form, `00005e005300`: the digits of [value] with the colons dropped, for a
  /// database key or a URL. IEEE sanctions it as a pure base-16 representation.
  String get bareHex => value.replaceAll(_colon, '');

  /// Orders two addresses lexicographically by their canonical form. Extension types cannot
  /// implement `Comparable<MacAddress>`, so this is a plain method, not the [Comparable] interface.
  int compareTo(MacAddress other) => value.compareTo(other.value);

  // Both special bits sit in the first octet, and a plain mask reads them: transmission order puts
  // the least significant bit of an octet on the wire first, so nothing needs reversing.
  bool _firstOctetHas(int bitMask) =>
      int.parse(value.substring(0, hexDigitsPerByte), radix: hexRadix) & bitMask != 0;

  // The canonical form: the stripped digits re-joined in pairs with a colon.
  static String _colonSeparated(String hex) => Iterable.generate(
    hex.length ~/ hexDigitsPerByte,
    (octet) => hex.substring(octet * hexDigitsPerByte, (octet + 1) * hexDigitsPerByte),
  ).join(_colon);

  // One anchored alternative per notation, so a spelling that mixes separators matches none.
  // The bare form takes digits in pairs, so an odd count fails the shape rather than miscounting.
  static final _notation = RegExp(
    '^(?:[0-9a-f]{2}(?::[0-9a-f]{2})*' // colon
    '|[0-9a-f]{2}(?:-[0-9a-f]{2})*' // hyphen
    r'|[0-9a-f]{4}(?:\.[0-9a-f]{4})*' // Cisco dot-quad
    r'|(?:[0-9a-f]{2})+)$', // bare hex
  );

  static final _separators = RegExp('[-:.]');

  static const _colon = ':';
  // The two widths IEEE 802 addresses come in: 48-bit (Ethernet, Wi-Fi) and 64-bit (802.15.4).
  static const _octetCounts = {6, 8};
  // Three octets of two hex digits, with the two colons between them.
  static const _prefix24Length = 8;
  static const _individualGroupBit = 0x01;
  static const _universalLocalBit = 0x02;
  static const _broadcast = 'ff:ff:ff:ff:ff:ff';
}
