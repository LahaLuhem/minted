/// @docImport '../uuid.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/outcomes/minted_failure.dart';

/// Why a [Uuid] refused its input. Sealed, not an enum, because [UuidWrongByteCount] reports a
/// count known only per call.
@immutable
sealed class UuidFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Uuid';
}

/// The text is not the canonical `8-4-4-4-12` hex form, wrapped or otherwise.
final class UuidMalformed extends UuidFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'not a well-formed UUID (expected 8-4-4-4-12 hex)';

  @override
  bool operator ==(Object other) => other is UuidMalformed;

  @override
  int get hashCode => (UuidMalformed).hashCode;

  @override
  String toString() => 'UuidMalformed()';
}

/// [Uuid.fromBytes] got other than 16 bytes. Every 16-byte sequence is a valid UUID, so length is
/// all it can reject.
final class UuidWrongByteCount extends UuidFailure {
  /// The byte count a UUID always has, `16`.
  final int expected;

  /// How many bytes were supplied.
  final int actual;

  /// Creates the failure.
  const new({required this.expected, required this.actual});

  @override
  String get message => 'expected $expected bytes, got $actual';

  @override
  bool operator ==(Object other) =>
      other is UuidWrongByteCount && other.expected == expected && other.actual == actual;

  @override
  int get hashCode => Object.hash(expected, actual);

  @override
  String toString() => 'UuidWrongByteCount(expected: $expected, actual: $actual)';
}
