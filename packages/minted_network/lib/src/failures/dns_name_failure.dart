/// @docImport '../dns_name.dart';
/// @docImport '../hostname.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [DnsName] refused its input. Sealed, not an enum, because most variants echo the part of
/// the input that failed.
///
/// Five where [Hostname] needs six: RFC 2181 drops the hyphen-edge and all-numeric-label rules, and
/// what is left is ASCII, a charset, an empty label, and the two length limits.
@immutable
sealed class DnsNameFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'DnsName';
}

/// Something outside ASCII survived normalisation, so this may be an internationalised name.
final class DnsNameNotAscii extends DnsNameFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'contains non-ASCII, so punycode it to an A-label first';

  @override
  bool operator ==(Object other) => other is DnsNameNotAscii;

  @override
  int get hashCode => (DnsNameNotAscii).hashCode;

  @override
  String toString() => 'DnsNameNotAscii()';
}

/// [character] is ASCII but outside the letters, digits, hyphen and underscore this type allows.
final class DnsNameInvalidCharacter extends DnsNameFailure {
  /// The first offending character.
  final String character;

  /// Creates the failure.
  const new(this.character);

  @override
  String get message => '"$character" is not a letter, digit, hyphen or underscore';

  @override
  bool operator ==(Object other) =>
      other is DnsNameInvalidCharacter && other.character == character;

  @override
  int get hashCode => Object.hash(DnsNameInvalidCharacter, character);

  @override
  String toString() => 'DnsNameInvalidCharacter($character)';
}

/// A label was empty, so two dots met or one sat at an edge. RFC 2181 gives a label one octet
/// minimum, which is the only shape rule left once the hyphen-edge rule goes.
final class DnsNameLabelEmpty extends DnsNameFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'has an empty label, so two dots met or one sits at an edge';

  @override
  bool operator ==(Object other) => other is DnsNameLabelEmpty;

  @override
  int get hashCode => (DnsNameLabelEmpty).hashCode;

  @override
  String toString() => 'DnsNameLabelEmpty()';
}

/// A label ran past the 63 octets RFC 2181 §11 allows one.
final class DnsNameLabelTooLong extends DnsNameFailure {
  /// How long the offending label was.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

  @override
  String get message => 'expected at most 63 characters per label, got $actualLength';

  @override
  bool operator ==(Object other) =>
      other is DnsNameLabelTooLong && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(DnsNameLabelTooLong, actualLength);

  @override
  String toString() => 'DnsNameLabelTooLong($actualLength)';
}

/// The whole name ran past 253 characters: RFC 1035's 255-octet wire limit, in presentation form.
final class DnsNameTooLong extends DnsNameFailure {
  /// How long the name was once normalised.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

  @override
  String get message => 'expected at most 253 characters, got $actualLength';

  @override
  bool operator ==(Object other) => other is DnsNameTooLong && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(DnsNameTooLong, actualLength);

  @override
  String toString() => 'DnsNameTooLong($actualLength)';
}
