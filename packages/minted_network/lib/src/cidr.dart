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

  // A block, not an address: what [IpAddress] used to carry until a `/` turned out not to parse there.
  //======================================== PRIVATE USE =========================================//

  /// `10.0.0.0/8`, the largest RFC 1918 block.
  static const private10 = Cidr._(_private10Network, 8);

  /// `172.16.0.0/12`, the middle RFC 1918 block.
  static const private172 = Cidr._(_private172Network, 12);

  /// `192.168.0.0/16`, the RFC 1918 block home routers hand out of.
  static const private192 = Cidr._(_private192Network, 16);

  /// `fc00::/7`, unique local addresses, which is v6's answer to RFC 1918. RFC 4193.
  static const uniqueLocalV6 = Cidr._(_uniqueLocalV6Network, 7);

  //==================================== SHARED ADDRESS SPACE ====================================//

  /// `100.64.0.0/10`, for carrier-grade NAT. RFC 6598 keeps this separate from RFC 1918 because it
  /// sits on the provider's side, so a subscriber can still use `10.0.0.0/8` behind it.
  static const sharedAddress = Cidr._(_sharedAddressNetwork, 10);

  //========================================= LINK-LOCAL =========================================//

  /// `169.254.0.0/16`, self-assigned when DHCP does not answer. RFC 3927.
  static const linkLocalV4 = Cidr._(_linkLocalV4Network, 16);

  /// `fe80::/10`, which every v6 interface has one of whether or not it is configured. RFC 4291.
  static const linkLocalV6 = Cidr._(_linkLocalV6Network, 10);

  //========================================= MULTICAST ==========================================//

  /// `224.0.0.0/4`, the old class D. RFC 5771.
  static const multicastV4 = Cidr._(_multicastV4Network, 4);

  /// `ff00::/8`. v6 has no broadcast, so this covers what broadcast used to do. RFC 4291.
  static const multicastV6 = Cidr._(_multicastV6Network, 8);

  //======================================= DOCUMENTATION ========================================//

  /// `192.0.2.0/24`, which RFC 5737 calls TEST-NET-1.
  static const docV4_1 = Cidr._(_docV4_1Network, 24);

  /// `198.51.100.0/24`, TEST-NET-2.
  static const docV4_2 = Cidr._(_docV4_2Network, 24);

  /// `203.0.113.0/24`, TEST-NET-3.
  static const docV4_3 = Cidr._(_docV4_3Network, 24);

  /// `2001:db8::/32`, the v6 documentation block. RFC 3849.
  static const docV6 = Cidr._(_docV6Network, 32);

  //======================================== IPV4-MAPPED =========================================//

  /// `::ffff:0.0.0.0/96`, where a v4 address sits when a dual-stack socket reports it as v6.
  /// RFC 4291 §2.5.5.2.
  static const v4MappedV6 = Cidr._(_v4MappedV6Network, 96);
}
