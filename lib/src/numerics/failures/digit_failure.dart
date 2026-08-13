/// @docImport '../digit.dart';
library;

import '../../shared/outcomes/minted_failure.dart';

/// Why a [Digit] refused its input. One variant: a one-character grammar has one way to fail.
@Deprecated('Digit.tryFrom returns null instead, so nothing produces this. Removed in 2.0.0 (#44).')
enum DigitFailure implements MintedFailure {
  /// The input is not a decimal digit `0`-`9`.
  notADigit('not a decimal digit 0-9');

  @Deprecated(
    'Digit.tryFrom returns null instead, so nothing produces this. Removed in 2.0.0 (#44).',
  )
  new(this.message);

  @override
  final String message;

  @override
  String get typeName => 'Digit';
}
