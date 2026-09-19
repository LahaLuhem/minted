/// @docImport '../phone_number.dart';
library;

import 'package:minted/minted.dart';

/// Why a [PhoneNumber] refused its input. Only [unknownCountryCallingCode] comes from the engine, which
/// throws one of its 5 codes in practice, so the rest get checked here.
enum PhoneNumberFailure implements MintedFailure {
  /// The `region` hint is no ISO 3166-1 alpha-2 code, so there was nothing to resolve against.
  unknownRegion('the region hint is not an ISO 3166-1 alpha-2 code'),

  /// No country calling code was recognised at the start, and no `region` supplied one.
  unknownCountryCallingCode('no country calling code recognised at the start'),

  /// The country is known but the digits don't form a real number for it.
  invalid('not a valid number for its country');

  new(this.message);

  @override
  final String message;

  @override
  String get typeName => 'PhoneNumber';
}
