/// @docImport '../digits.dart';
library;

import '../../shared/outcomes/minted_failure.dart';

/// Why a [Digits] sequence refused its input. One variant: naming which element offended would
/// not change the remedy.
enum DigitsFailure implements MintedFailure {
  /// Something in the input is not a decimal digit `0`-`9`.
  notAllDigits('not all decimal digits 0-9');

  new(this.message);

  @override
  final String message;

  @override
  String get typeName => 'Digits';
}
