/// @docImport '../hostname.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/outcomes/minted_failure.dart';

/// Why a [Hostname] refused its input. Sealed, not an enum, because most variants echo the part of
/// the input that failed.
///
/// Six where most types need three, because RFC 1123 stacks that many independent rules: ASCII, a
/// charset, two length limits, a label shape, and the not-an-address rule.
@immutable
sealed class HostnameFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Hostname';
}

/// Something outside ASCII survived normalisation, so this may be an internationalised name.
final class HostnameNotAscii extends HostnameFailure {
  /// Creates the failure.
  const new();

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
final class HostnameInvalidCharacters extends HostnameFailure {
  /// The first offending character.
  final String character;

  /// Creates the failure.
  const new(this.character);

  // An underscore is the one that is valid somewhere else, so it is named rather than lumped in.
  @override
  String get message => character == '_'
      ? 'an underscore makes this a DNS name, not a hostname'
      : '"$character" is not a letter, digit or hyphen';

  @override
  bool operator ==(Object other) =>
      other is HostnameInvalidCharacters && other.character == character;

  @override
  int get hashCode => Object.hash(HostnameInvalidCharacters, character);

  @override
  String toString() => 'HostnameInvalidCharacters($character)';
}

/// [label] is empty, or opens or closes with a hyphen, which RFC 1123 reserves for the interior.
final class HostnameLabelMalformed extends HostnameFailure {
  /// The offending label, empty when two dots met.
  final String label;

  /// Creates the failure.
  const new(this.label);

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
final class HostnameLabelTooLong extends HostnameFailure {
  /// How long the offending label was.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

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

/// The whole name ran past 253 characters: RFC 1035's 255-octet wire limit, in presentation form.
final class HostnameTooLong extends HostnameFailure {
  /// How long the name was once normalised.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

  @override
  String get message => 'expected at most 253 characters, got $actualLength';

  @override
  bool operator ==(Object other) => other is HostnameTooLong && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(HostnameTooLong, actualLength);

  @override
  String toString() => 'HostnameTooLong($actualLength)';
}

/// The last label is all digits, which RFC 1123 says a host name never is. It is an address.
final class HostnameNumericTld extends HostnameFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'ends in an all-numeric label, so this is an address, not a hostname';

  @override
  bool operator ==(Object other) => other is HostnameNumericTld;

  @override
  int get hashCode => (HostnameNumericTld).hashCode;

  @override
  String toString() => 'HostnameNumericTld()';
}
