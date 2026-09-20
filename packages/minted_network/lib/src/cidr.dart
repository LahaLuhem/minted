part of 'ip_address.dart';

/// A CIDR block: a network address and how many leading bits of it the prefix covers, written
/// `10.0.0.0/8` or `2001:db8::/32`.
/// Standards: [RFC 4632](https://www.rfc-editor.org/rfc/rfc4632) for v4,
/// [RFC 4291 §2.3](https://www.rfc-editor.org/rfc/rfc4291#section-2.3) for v6.
///
/// [network] is an [IpAddress], not a slice of text, so [contains] masks bits. Match on the text and
/// `10.0.0.0/8` looks like it covers `100.0.0.1`. Why: `/APPENDIX.md#compose-from-modelled-parts`.
///
/// > [!IMPORTANT]
/// > **Host bits must be clear.** `192.168.1.5/24` is refused rather than masked to
/// > `192.168.1.0/24`, and the failure carries the block most likely meant.
/// > Why: `APPENDIX.md#cidr-value-type`.
///
/// Named values: [CidrConstants].
///
/// {@example /example/minted_network_example.dart#cidr}
@immutable
final class const Cidr._(
  /// The network address, every bit below [prefixLength] clear.
  final IpAddress network,

  /// How many leading bits the prefix covers: `0` to `32` for v4, `0` to `128` for v6.
  final int prefixLength,
) {
  /// The block at [network] covering [prefixLength] bits, reporting the [CidrFailure] when the prefix
  /// does not fit the family or [network] has bits set below it.
  static ParseOutcome<CidrFailure, Cidr> from({
    required IpAddress network,
    required int prefixLength,
  }) => parse('${network.value}$_prefixSeparator$prefixLength');

  /// Parses [input], or `null` if it isn't a CIDR block.
  static Cidr? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [CidrFailure] saying which rule broke.
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

  /// The last address the block covers, which for v4 is what other tools call the broadcast address.
  /// Named for what it is, since IPv6 has no broadcast.
  // The octet count comes from an address that already parsed, so fromOctets cannot fail here.
  IpAddress get lastAddress {
    final octets = network.octets;

    return IpAddress.fromOctets(
      Uint8List.fromList([
        for (var index = 0; index < octets.length; index++)
          octets[index] | ~_octetMaskAt(index, prefixLength) & _allOctetBits,
      ]),
    ).getOrThrow();
  }

  /// Whether [address] falls inside this block. A different family is never inside, so a v6 address
  /// is not in `10.0.0.0/8`.
  bool contains(IpAddress address) =>
      address.version == network.version && _masked(address, prefixLength) == network;

  @override
  bool operator ==(Object other) =>
      other is Cidr && other.network == network && other.prefixLength == prefixLength;

  @override
  int get hashCode => Object.hash(network, prefixLength);

  @override
  String toString() => 'Cidr(network: ${network.value}, prefixLength: $prefixLength)';
}
