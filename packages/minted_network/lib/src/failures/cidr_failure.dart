/// @docImport '../cidr.dart';
/// @docImport '../ip_address.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

import 'ip_address_failure.dart';

/// Why a [Cidr] refused its input. Sealed rather than an enum, because 3 variants carry what failed,
/// one of them another type's failure.
@immutable
sealed class const CidrFailure() implements MintedFailure {
  /// Subclasses only: the type is sealed.
  this;

  @override
  String get typeName => 'Cidr';
}

/// The text isn't an address followed by `/` and a decimal prefix length.
final class const CidrMalformed() extends CidrFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'not an address followed by / and a prefix length';

  @override
  bool operator ==(Object other) => other is CidrMalformed;

  @override
  int get hashCode => (CidrMalformed).hashCode;

  @override
  String toString() => 'CidrMalformed()';
}

/// The part before the `/` isn't an [IpAddress], and [reason] says why.
///
/// Nested rather than flattened so the diagnosis survives: a caller learns the address had a leading
/// zero, not just that something about it was wrong.
final class const CidrInvalidAddress(
  /// Why the address itself would not parse.
  final IpAddressFailure reason,
) extends CidrFailure {
  /// Creates the failure.
  this;

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
final class const CidrPrefixLengthOutOfRange({
  /// The widest prefix the address family allows: 32 for v4, 128 for v6.
  required final int maxPrefixLength,

  /// The prefix length supplied.
  required final int actual,
}) extends CidrFailure {
  /// Creates the failure.
  this;

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

/// Bits are set below the prefix, so this names a host rather than a network. [networkAddress] is the
/// block the caller most likely meant.
final class const CidrHostBitsSet(
  /// The input with its host bits cleared, offered as the likely intent.
  final String networkAddress,
) extends CidrFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'has host bits set below the prefix. The network is "$networkAddress"';

  @override
  bool operator ==(Object other) =>
      other is CidrHostBitsSet && other.networkAddress == networkAddress;

  @override
  int get hashCode => Object.hash(CidrHostBitsSet, networkAddress);

  @override
  String toString() => 'CidrHostBitsSet($networkAddress)';
}
