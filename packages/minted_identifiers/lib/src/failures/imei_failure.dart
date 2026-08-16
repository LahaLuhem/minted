/// @docImport '../imei.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why an [Imei] refused its input. Sealed, not an enum, because [ImeiWrongLength] reports a value
/// read from the input.
///
/// Three variants: 3GPP TS 23.003 gives an IMEI a digit charset, one length, and a check digit.
@immutable
sealed class ImeiFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Imei';
}

/// Not fifteen digits, so this is not an IMEI. Sixteen is named as the IMEISV it is rather than called
/// a miscount.
final class ImeiWrongLength extends ImeiFailure {
  /// How many digits were left once separators were stripped.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

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

  // An IMEISV trades the check digit for a two-digit software version, so it is a real identifier for
  // the same handset, just not this one.
  static const _imeisvLength = 16;
}

/// Something outside `0`-`9` survived normalisation (spaces and hyphens are stripped first).
final class ImeiInvalidCharacters extends ImeiFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'contains characters outside 0-9';

  @override
  bool operator ==(Object other) => other is ImeiInvalidCharacters;

  @override
  int get hashCode => (ImeiInvalidCharacters).hashCode;

  @override
  String toString() => 'ImeiInvalidCharacters()';
}

/// The check digit disagrees with the rest of the number: a digit is mistyped or transposed.
final class ImeiChecksumFailed extends ImeiFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'failed the Luhn check';

  @override
  bool operator ==(Object other) => other is ImeiChecksumFailed;

  @override
  int get hashCode => (ImeiChecksumFailed).hashCode;

  @override
  String toString() => 'ImeiChecksumFailed()';
}
