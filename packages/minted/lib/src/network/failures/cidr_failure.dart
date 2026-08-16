/// @docImport '../cidr.dart';
/// @docImport '../ip_address.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/outcomes/minted_failure.dart';
import 'ip_address_failure.dart';

/// Why a [Cidr] refused its input. Sealed, not an enum, because three variants carry what failed,
/// one of them another type's failure.
@immutable
sealed class CidrFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Cidr';
}

/// The text is not an address followed by `/` and a decimal prefix length.
final class CidrMalformed extends CidrFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'not an address followed by / and a prefix length';

  @override
  bool operator ==(Object other) => other is CidrMalformed;

  @override
  int get hashCode => (CidrMalformed).hashCode;

  @override
  String toString() => 'CidrMalformed()';
}

/// The part before the `/` is not an [IpAddress], and [reason] says why.
///
/// Nested rather than flattened so the diagnosis survives: a caller learns that the address had a
/// leading zero, not merely that something about it was wrong.
final class CidrInvalidAddress extends CidrFailure {
  /// Why the address itself would not parse.
  final IpAddressFailure reason;

  /// Creates the failure.
  const new(this.reason);

  @override
  String get message => 'the network address is invalid: ${reason.message}';

  @override
  bool operator ==(Object other) => other is CidrInvalidAddress && other.reason == reason;

  @override
  int get hashCode => Object.hash(CidrInvalidAddress, reason);

  @override
  String toString() => 'CidrInvalidAddress($reason)';
}

/// The prefix length is a number, but not one this family has bits for.
final class CidrPrefixLengthOutOfRange extends CidrFailure {
  /// The widest prefix the address family allows: 32 for v4, 128 for v6.
  final int maxPrefixLength;

  /// The prefix length supplied.
  final int actual;

  /// Creates the failure.
  const new({required this.maxPrefixLength, required this.actual});

  @override
  String get message => 'expected a prefix length of 0 to $maxPrefixLength, got $actual';

  @override
  bool operator ==(Object other) =>
      other is CidrPrefixLengthOutOfRange &&
      other.maxPrefixLength == maxPrefixLength &&
      other.actual == actual;

  @override
  int get hashCode => Object.hash(maxPrefixLength, actual);

  @override
  String toString() =>
      'CidrPrefixLengthOutOfRange(maxPrefixLength: $maxPrefixLength, actual: $actual)';
}

/// Bits are set below the prefix, so this names a host rather than a network. [networkAddress] is
/// the block the caller most likely meant.
final class CidrHostBitsSet extends CidrFailure {
  /// The input with its host bits cleared, offered as the likely intent.
  final String networkAddress;

  /// Creates the failure.
  const new(this.networkAddress);

  @override
  String get message => 'has host bits set below the prefix; the network is "$networkAddress"';

  @override
  bool operator ==(Object other) =>
      other is CidrHostBitsSet && other.networkAddress == networkAddress;

  @override
  int get hashCode => Object.hash(CidrHostBitsSet, networkAddress);

  @override
  String toString() => 'CidrHostBitsSet($networkAddress)';
}
