/// @docImport '../imei.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why an [Imei] refused its input. Sealed rather than an enum, because [ImeiWrongLength] carries a
/// number off the input.
@immutable
sealed class const ImeiFailure() implements MintedFailure {
  @override
  String get typeName => 'Imei';
}

/// Not 15 digits. 16 gets called out as the IMEISV it is.
final class const ImeiWrongLength(
  /// How many digits were left after separators came off.
  final int actualLength,
) extends ImeiFailure {
  /// Creates the failure.
  this;

  @override
  String get message => actualLength == _imeisvLength
      ? '16 digits is an IMEISV, not an IMEI'
      : 'expected 15 digits, got $actualLength';

  @override
  bool operator ==(Object other) => other is ImeiWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(ImeiWrongLength, actualLength);

  @override
  String toString() => 'ImeiWrongLength($actualLength)';

  // An IMEISV swaps the check digit for a 2-digit software version, so it's a real identifier for
  // the same handset, just not this one.
  static const _imeisvLength = 16;
}

/// Something outside `0`-`9` got through. Spaces and hyphens come off first.
final class const ImeiInvalidCharacters() extends ImeiFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'contains characters outside 0-9';

  @override
  bool operator ==(Object other) => other is ImeiInvalidCharacters;

  @override
  int get hashCode => (ImeiInvalidCharacters).hashCode;

  @override
  String toString() => 'ImeiInvalidCharacters()';
}

/// The check digit doesn't match the rest. A digit is mistyped or swapped.
final class const ImeiChecksumFailed() extends ImeiFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'failed the Luhn check';

  @override
  bool operator ==(Object other) => other is ImeiChecksumFailed;

  @override
  int get hashCode => (ImeiChecksumFailed).hashCode;

  @override
  String toString() => 'ImeiChecksumFailed()';
}
