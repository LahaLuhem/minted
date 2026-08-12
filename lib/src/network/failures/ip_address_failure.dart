/// @docImport '../ip_address.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/minted_failure.dart';

/// Why an [IpAddress] refused its input. Sealed, not an enum, because three variants echo the part
/// of the input that failed.
@immutable
sealed class IpAddressFailure implements MintedFailure {
  const IpAddressFailure();

  @override
  String get typeName => 'IpAddress';
}

/// The text is neither a dotted quad nor an RFC 4291 IPv6 address.
final class IpAddressMalformed extends IpAddressFailure {
  /// Creates the failure.
  const IpAddressMalformed();

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
/// `inet_aton` reads `010` as octal 8 where most parsers read decimal 10, so accepting it lets one
/// component filter an address a second then connects to. Why: `APPENDIX.md#ip-address-value-type`.
final class IpAddressLeadingZero extends IpAddressFailure {
  /// The offending part, as written.
  final String part;

  /// Creates the failure.
  const IpAddressLeadingZero(this.part);

  @override
  String get message => '"$part" has a leading zero, which is ambiguous between decimal and octal';

  @override
  bool operator ==(Object other) => other is IpAddressLeadingZero && other.part == part;

  @override
  int get hashCode => Object.hash(IpAddressLeadingZero, part);

  @override
  String toString() => 'IpAddressLeadingZero($part)';
}

/// [part] is a well-formed number that does not fit its field: an octet past 255, or a hextet past
/// four digits.
final class IpAddressPartOutOfRange extends IpAddressFailure {
  /// The offending part, as written.
  final String part;

  /// Creates the failure.
  const IpAddressPartOutOfRange(this.part);

  @override
  String get message => '"$part" is outside the range its field allows';

  @override
  bool operator ==(Object other) => other is IpAddressPartOutOfRange && other.part == part;

  @override
  int get hashCode => Object.hash(IpAddressPartOutOfRange, part);

  @override
  String toString() => 'IpAddressPartOutOfRange($part)';
}

/// [IpAddress.fromOctets] got other than the 4 octets of IPv4 or the 16 of IPv6.
final class IpAddressWrongOctetCount extends IpAddressFailure {
  /// How many octets were supplied.
  final int actual;

  /// Creates the failure.
  const IpAddressWrongOctetCount(this.actual);

  @override
  String get message => 'expected 4 or 16 octets, got $actual';

  @override
  bool operator ==(Object other) => other is IpAddressWrongOctetCount && other.actual == actual;

  @override
  int get hashCode => Object.hash(IpAddressWrongOctetCount, actual);

  @override
  String toString() => 'IpAddressWrongOctetCount($actual)';
}
