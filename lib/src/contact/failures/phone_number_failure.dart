/// @docImport '../phone_number.dart';
library;

import '../../shared/minted_failure.dart';

/// Why a [PhoneNumber] refused its input.
enum PhoneNumberFailure implements MintedFailure {
  /// The input is not a valid phone number.
  invalid('not a valid phone number');

  const PhoneNumberFailure(this.message);

  @override
  final String message;

  @override
  String get typeName => 'PhoneNumber';
}
