/// @docImport '../digits.dart';
library;

import '../../shared/outcomes/minted_failure.dart';

/// Why a [Digits] sequence refused its input. One variant: naming which element offended would
/// not change the remedy.
@Deprecated(
  'Digits.tryFrom returns null instead, so nothing produces this. Removed in 2.0.0 (#44).',
)
enum DigitsFailure implements MintedFailure {
  /// Something in the input is not a decimal digit `0`-`9`.
  notAllDigits('not all decimal digits 0-9');

  @Deprecated(
    'Digits.tryFrom returns null instead, so nothing produces this. Removed in 2.0.0 (#44).',
  )
  new(this.message);

  @override
  final String message;

  @override
  String get typeName => 'Digits';
}
