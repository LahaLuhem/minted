/// @docImport '../hostname.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [Hostname] refused its input. Sealed rather than an enum, because most variants echo the part
/// of the input that failed.
///
/// Twice the usual 3, because RFC 1123 stacks that many independent rules.
@immutable
sealed class const HostnameFailure() implements MintedFailure {
  @override
  String get typeName => 'Hostname';
}

/// Something outside ASCII got through, so this may be an internationalised name.
final class const HostnameNotAscii() extends HostnameFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'contains non-ASCII, so punycode it to an A-label first';

  @override
  bool operator ==(Object other) => other is HostnameNotAscii;

  @override
  int get hashCode => (HostnameNotAscii).hashCode;

  @override
  String toString() => 'HostnameNotAscii()';
}

/// [character] is ASCII but outside the letters, digits and hyphen RFC 1123 allows.
final class const HostnameInvalidCharacter(
  /// The first offending character.
  final String character,
) extends HostnameFailure {
  /// Creates the failure.
  this;

  // An underscore is the one that's valid somewhere else, so it gets named rather than lumped in.
  @override
  String get message => character == '_'
      ? 'an underscore makes this a DNS name, not a hostname'
      : '"$character" is not a letter, digit or hyphen';

  @override
  bool operator ==(Object other) =>
      other is HostnameInvalidCharacter && other.character == character;

  @override
  int get hashCode => Object.hash(HostnameInvalidCharacter, character);

  @override
  String toString() => 'HostnameInvalidCharacter($character)';
}

/// [label] is empty, or opens or closes with a hyphen, which RFC 1123 keeps for the interior.
final class const HostnameLabelMalformed(
  /// The offending label, empty when 2 dots met.
  final String label,
) extends HostnameFailure {
  /// Creates the failure.
  this;

  @override
  String get message => label.isEmpty
      ? 'has an empty label, so two dots met or one sits at an edge'
      : '"$label" opens or closes with a hyphen';

  @override
  bool operator ==(Object other) => other is HostnameLabelMalformed && other.label == label;

  @override
  int get hashCode => Object.hash(HostnameLabelMalformed, label);

  @override
  String toString() => 'HostnameLabelMalformed($label)';
}

/// A label ran past the 63 octets RFC 1035 allows one.
final class const HostnameLabelTooLong(
  /// How long the offending label was.
  final int actualLength,
) extends HostnameFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'expected at most 63 characters per label, got $actualLength';

  @override
  bool operator ==(Object other) =>
      other is HostnameLabelTooLong && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(HostnameLabelTooLong, actualLength);

  @override
  String toString() => 'HostnameLabelTooLong($actualLength)';
}

/// The whole name ran past 253 characters, RFC 1035's 255-octet wire limit in presentation form.
final class const HostnameTooLong(
  /// How long the name was once normalised.
  final int actualLength,
) extends HostnameFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'expected at most 253 characters, got $actualLength';

  @override
  bool operator ==(Object other) => other is HostnameTooLong && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(HostnameTooLong, actualLength);

  @override
  String toString() => 'HostnameTooLong($actualLength)';
}

/// The last label is all digits, which RFC 1123 says a host name never is. That's an address.
final class const HostnameNumericTld() extends HostnameFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'ends in an all-numeric label, so this is an address, not a hostname';

  @override
  bool operator ==(Object other) => other is HostnameNumericTld;

  @override
  int get hashCode => (HostnameNumericTld).hashCode;

  @override
  String toString() => 'HostnameNumericTld()';
}
