import 'dart:math';

import 'package:meta/meta.dart';

import '../shared/minted_format_exception.dart';
import '../shared/normalisation.dart';
import '../shared/octet_bits.dart';
import '../shared/parse_outcome.dart';
import 'failures/cidr_failure.dart';
import 'ip_address.dart';

/// A CIDR block: a network address and how many leading bits of it the prefix covers, written
/// `10.0.0.0/8` or `2001:db8::/32`.
/// Standards: [RFC 4632](https://www.rfc-editor.org/rfc/rfc4632) for v4,
/// [RFC 4291 §2.3](https://www.rfc-editor.org/rfc/rfc4291#section-2.3) for v6.
///
/// Parse, don't validate: firewall rules and allow-lists keep these as strings, and [contains] then
/// gets hand-rolled as a prefix match on the text, which reads `10.0.0.0/8` as covering `10.1.2.3`
/// and `100.0.0.1` alike.
///
/// **Host bits must be clear.** `192.168.1.5/24` is refused rather than quietly masked to
/// `192.168.1.0/24`, because masking discards an address the caller wrote; the failure offers the
/// block they most likely meant. Why: `APPENDIX.md#cidr-value-type`.
///
/// Holds an [IpAddress] rather than slicing one back out of its own text, so the network address
/// cannot be malformed and [contains] cannot be handed something that merely looks like an address.
/// Why: `APPENDIX.md#compose-from-modelled-parts`.
@immutable
final class Cidr {
  /// The network address, every bit below [prefixLength] clear.
  final IpAddress network;

  /// How many leading bits the prefix covers: `0` to `32` for v4, `0` to `128` for v6.
  final int prefixLength;

  const new _(this.network, this.prefixLength);

  /// The block at [network] covering [prefixLength] bits, throwing [MintedFormatException] when the
  /// prefix does not fit the family or [network] has bits set below it.
  static Cidr from({required IpAddress network, required int prefixLength}) {
    final source = '${network.value}$_prefixSeparator$prefixLength';

    return parse(
      source,
    ).fold((reason) => throw MintedFormatException.from(reason, source), (cidr) => cidr);
  }

  /// Parses [input] as a CIDR block, or returns `null` when it is not one.
  /// See the type docs for what is refused.
  static Cidr? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a CIDR block, reporting the [CidrFailure] saying which rule broke.
  static ParseOutcome<CidrFailure, Cidr> parse(String input) {
    final parts = input.trim().split(_prefixSeparator);
    if (parts.length != _partCount) return const ParseFailure(CidrMalformed());

    return IpAddress.parse(parts.first).fold(
      (reason) => ParseFailure(CidrInvalidAddress(reason)),
      (network) => _withPrefix(network, parts.last),
    );
  }

  /// The canonical text, `10.0.0.0/8`. Round-trips through [parse].
  String get asString => '${network.value}$_prefixSeparator$prefixLength';

  /// The last address the block covers, which for v4 is what other tools call the broadcast
  /// address. Named for what it is, since IPv6 has no broadcast at all.
  IpAddress get lastAddress {
    final octets = network.octets;

    return .fromOctets(
      .fromList([
        for (var index = 0; index < octets.length; index++)
          octets[index] | ~_octetMask(index, prefixLength) & _allOctetBits,
      ]),
    );
  }

  /// Whether [address] falls inside this block. A different family is never inside, so a v6 address
  /// is not in `10.0.0.0/8`; the two do not compare.
  bool contains(IpAddress address) =>
      address.version == network.version && _masked(address, prefixLength) == network;

  @override
  bool operator ==(Object other) =>
      other is Cidr && other.network == network && other.prefixLength == prefixLength;

  @override
  int get hashCode => Object.hash(network, prefixLength);

  @override
  String toString() => 'Cidr(network: ${network.value}, prefixLength: $prefixLength)';

  // Split out so parse reads as its two stages: the address, then everything the address decides.
  static ParseOutcome<CidrFailure, Cidr> _withPrefix(IpAddress network, String prefixText) {
    if (!digitsOnly.hasMatch(prefixText)) return const ParseFailure(CidrMalformed());

    final maxPrefixLength = _maxPrefixLengthFor(network.version);
    final prefixLength = int.parse(prefixText);
    if (prefixLength > maxPrefixLength) {
      return ParseFailure(
        CidrPrefixLengthOutOfRange(maxPrefixLength: maxPrefixLength, actual: prefixLength),
      );
    }

    final masked = _masked(network, prefixLength);

    return masked != network
        ? ParseFailure(CidrHostBitsSet('${masked.value}$_prefixSeparator$prefixLength'))
        : ParseSuccess(Cidr._(network, prefixLength));
  }

  static IpAddress _masked(IpAddress address, int prefixLength) {
    final octets = address.octets;

    return .fromOctets(
      .fromList([
        for (var index = 0; index < octets.length; index++)
          octets[index] & _octetMask(index, prefixLength),
      ]),
    );
  }

  // The prefix eats whole octets until it runs out, then covers the top bits of one more. min/max
  // rather than clamp, which is declared on num and would widen the shift operand.
  static int _octetMask(int index, int prefixLength) {
    final coveredBits = min(max(prefixLength - index * bitsPerOctet, 0), bitsPerOctet);

    return _allOctetBits << (bitsPerOctet - coveredBits) & _allOctetBits;
  }

  static int _maxPrefixLengthFor(IpVersion version) => switch (version) {
    .v4 => _maxV4PrefixLength,
    .v6 => _maxV6PrefixLength,
  };

  static const _prefixSeparator = '/';
  static const _partCount = 2;
  static const _allOctetBits = 0xff;
  static const _maxV4PrefixLength = 32;
  static const _maxV6PrefixLength = 128;
}
