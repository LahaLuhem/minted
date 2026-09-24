// Not '../short_plus_code.dart': it is a part, and doc-importing a part crashes the analyzer.
// https://github.com/dart-lang/sdk/issues/56013#issuecomment-5757258757
/// @docImport '../plus_code.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [PlusCode] or [ShortPlusCode] refused its input. Sealed rather than an enum, because the 2
/// wrong-kind variants hand the code back so a caller can route it to the other type.
@immutable
sealed class const PlusCodeFailure() implements MintedFailure {
  /// Subclasses only: the type is sealed.
  this;

  @override
  String get typeName => 'PlusCode';
}

/// The text is no Plus Code at all: a character outside the alphabet, a separator in the wrong place
/// or missing, or padding with digits after it.
final class const PlusCodeMalformed() extends PlusCodeFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'not a well-formed Plus Code';

  @override
  bool operator ==(Object other) => other is PlusCodeMalformed;

  @override
  int get hashCode => (PlusCodeMalformed).hashCode;

  @override
  String toString() => 'PlusCodeMalformed()';
}

/// A real Plus Code, but a shortened one, where [PlusCode] holds only full codes.
final class const PlusCodeNotFull(
  /// The code, ready for [ShortPlusCode.tryParse].
  final String code,
) extends PlusCodeFailure {
  /// Creates the failure.
  this;

  @override
  String get message => '"$code" is a short code, which needs a reference location to recover';

  @override
  bool operator ==(Object other) => other is PlusCodeNotFull && other.code == code;

  @override
  int get hashCode => Object.hash(PlusCodeNotFull, code);

  @override
  String toString() => 'PlusCodeNotFull($code)';
}

/// A real Plus Code, but a full one, where [ShortPlusCode] holds only shortened codes.
final class const PlusCodeNotShort(
  /// The code, ready for [PlusCode.tryParse].
  final String code,
) extends PlusCodeFailure {
  /// Creates the failure.
  this;

  @override
  String get message => '"$code" is a full code, which names a place on its own';

  @override
  bool operator ==(Object other) => other is PlusCodeNotShort && other.code == code;

  @override
  int get hashCode => Object.hash(PlusCodeNotShort, code);

  @override
  String toString() => 'PlusCodeNotShort($code)';
}
