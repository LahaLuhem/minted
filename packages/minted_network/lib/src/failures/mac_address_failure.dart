/// @docImport '../mac_address.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [MacAddress] refused its input. Sealed rather than an enum, because [MacAddressWrongOctetCount]
/// carries a count off the input.
///
/// 2, one per remedy: fix the notation, or fix the width. IEEE 802 has no checksum and no reserved
/// address, so nothing else can fail.
@immutable
sealed class const MacAddressFailure() implements MintedFailure {
  /// Subclasses only: the type is sealed.
  this;

  @override
  String get typeName => 'MacAddress';
}

/// The text is none of the 4 accepted notations, or mixes 2 of them.
final class const MacAddressMalformed() extends MacAddressFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'not a colon, hyphen, dot-quad or bare-hex MAC address';

  @override
  bool operator ==(Object other) => other is MacAddressMalformed;

  @override
  int get hashCode => (MacAddressMalformed).hashCode;

  @override
  String toString() => 'MacAddressMalformed()';
}

/// The notation was recognised but held neither 6 octets (48-bit) nor 8 (64-bit). Also what
/// [MacAddress.fromOctets] turns down.
final class const MacAddressWrongOctetCount(
  /// How many octets were supplied.
  final int actual,
) extends MacAddressFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'expected 6 or 8 octets, got $actual';

  @override
  bool operator ==(Object other) => other is MacAddressWrongOctetCount && other.actual == actual;

  @override
  int get hashCode => Object.hash(MacAddressWrongOctetCount, actual);

  @override
  String toString() => 'MacAddressWrongOctetCount($actual)';
}
