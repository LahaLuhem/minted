part of '../ip_address.dart';

// Split out so parse reads as its 2 stages: the address, then everything the address decides.
ParseOutcome<CidrFailure, Cidr> _withPrefix(IpAddress network, String prefixText) {
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

// As lastAddress: the octets come from a parsed address, so the count is already right.
IpAddress _masked(IpAddress address, int prefixLength) {
  final octets = address.octets;

  return IpAddress.fromOctets(
    Uint8List.fromList([
      for (var index = 0; index < octets.length; index++)
        octets[index] & _octetMaskAt(index, prefixLength),
    ]),
  ).getOrThrow();
}

// The prefix eats whole octets until it runs out, then covers the top bits of one more. min/max rather
// than clamp, which is declared on num and would widen the shift operand.
int _octetMaskAt(int index, int prefixLength) {
  final coveredBits = min(max(prefixLength - index * bitsPerOctet, 0), bitsPerOctet);

  return _allOctetBits << (bitsPerOctet - coveredBits) & _allOctetBits;
}

int _maxPrefixLengthFor(IpVersion version) => switch (version) {
  .v4 => _maxV4PrefixLength,
  .v6 => _maxV6PrefixLength,
};

const _prefixSeparator = '/';
const _partCount = 2;
const _allOctetBits = 0xff;
const _maxV4PrefixLength = 32;
const _maxV6PrefixLength = 128;
