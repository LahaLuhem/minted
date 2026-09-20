/// @docImport '../ip_address.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why an [IpAddress] refused its input. Sealed rather than an enum, because 3 variants echo the
/// part of the input that failed.
@immutable
sealed class const IpAddressFailure() implements MintedFailure {
  @override
  String get typeName => 'IpAddress';
}

/// The text is neither a dotted quad nor an RFC 4291 IPv6 address.
final class const IpAddressMalformed() extends IpAddressFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'not a dotted-quad or IPv6 address';

  @override
  bool operator ==(Object other) => other is IpAddressMalformed;

  @override
  int get hashCode => (IpAddressMalformed).hashCode;

  @override
  String toString() => 'IpAddressMalformed()';
}

/// [part] carries a leading zero, which is refused rather than read.
///
/// `inet_aton` reads `010` as octal 8 where most parsers read decimal 10, so taking it lets one component
/// filter an address that another then connects to. Why: `APPENDIX.md#ip-address-value-type`.
final class const IpAddressLeadingZero(
  /// The offending part, as written.
  final String part,
) extends IpAddressFailure {
  /// Creates the failure.
  this;

  @override
  String get message => '"$part" has a leading zero, which is ambiguous between decimal and octal';

  @override
  bool operator ==(Object other) => other is IpAddressLeadingZero && other.part == part;

  @override
  int get hashCode => Object.hash(IpAddressLeadingZero, part);

  @override
  String toString() => 'IpAddressLeadingZero($part)';
}

/// [part] is a well-formed number that doesn't fit its field: an octet past 255, or a hextet past 4
/// digits.
final class const IpAddressPartOutOfRange(
  /// The offending part, as written.
  final String part,
) extends IpAddressFailure {
  /// Creates the failure.
  this;

  @override
  String get message => '"$part" is outside the range its field allows';

  @override
  bool operator ==(Object other) => other is IpAddressPartOutOfRange && other.part == part;

  @override
  int get hashCode => Object.hash(IpAddressPartOutOfRange, part);

  @override
  String toString() => 'IpAddressPartOutOfRange($part)';
}

/// [IpAddress.fromOctets] got neither the 4 octets of IPv4 nor the 16 of IPv6.
final class const IpAddressWrongOctetCount(
  /// How many octets were supplied.
  final int actual,
) extends IpAddressFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'expected 4 or 16 octets, got $actual';

  @override
  bool operator ==(Object other) => other is IpAddressWrongOctetCount && other.actual == actual;

  @override
  int get hashCode => Object.hash(IpAddressWrongOctetCount, actual);

  @override
  String toString() => 'IpAddressWrongOctetCount($actual)';
}
