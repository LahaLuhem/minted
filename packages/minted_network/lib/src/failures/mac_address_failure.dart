/// @docImport '../mac_address.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [MacAddress] refused its input. Sealed, not an enum, because [MacAddressWrongOctetCount]
/// reports a count read from the input.
///
/// Two variants, one per remedy: fix the notation, or fix the width. IEEE 802 has no checksum and
/// no reserved address, so nothing else can fail.
@immutable
sealed class MacAddressFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'MacAddress';
}

/// The text is none of the four accepted notations, or mixes two of them.
final class MacAddressMalformed extends MacAddressFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'not a colon, hyphen, dot-quad or bare-hex MAC address';

  @override
  bool operator ==(Object other) => other is MacAddressMalformed;

  @override
  int get hashCode => (MacAddressMalformed).hashCode;

  @override
  String toString() => 'MacAddressMalformed()';
}

/// The notation was recognised but held neither six octets (48-bit) nor eight (64-bit). Also what
/// [MacAddress.fromOctets] rejects.
final class MacAddressWrongOctetCount extends MacAddressFailure {
  /// How many octets were supplied.
  final int actual;

  /// Creates the failure.
  const new(this.actual);

  @override
  String get message => 'expected 6 or 8 octets, got $actual';

  @override
  bool operator ==(Object other) => other is MacAddressWrongOctetCount && other.actual == actual;

  @override
  int get hashCode => Object.hash(MacAddressWrongOctetCount, actual);

  @override
  String toString() => 'MacAddressWrongOctetCount($actual)';
}
