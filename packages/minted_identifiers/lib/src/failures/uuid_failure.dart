/// @docImport '../uuid.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [Uuid] refused its input. Sealed rather than an enum, because [UuidWrongByteCount] carries
/// a count known only per call.
@immutable
sealed class const UuidFailure() implements MintedFailure {
  @override
  String get typeName => 'Uuid';
}

/// The text isn't `8-4-4-4-12` hex, wrapped or not.
final class const UuidMalformed() extends UuidFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'not a well-formed UUID (expected 8-4-4-4-12 hex)';

  @override
  bool operator ==(Object other) => other is UuidMalformed;

  @override
  int get hashCode => (UuidMalformed).hashCode;

  @override
  String toString() => 'UuidMalformed()';
}

/// [Uuid.fromBytes] got something other than 16 bytes. Every 16-byte sequence is a valid UUID, so length
/// is all it can turn down.
final class const UuidWrongByteCount({
  /// The byte count a UUID always has, `16`.
  required final int expected,

  /// How many bytes turned up.
  required final int actual,
}) extends UuidFailure {
  /// Creates the failure.
  this;

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
