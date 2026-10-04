/// @docImport '../phone_number.dart';
library;

import 'package:minted/minted.dart';

/// Why a [PhoneNumber] refused its input.
enum PhoneNumberFailure(@override final String message) implements MintedFailure {
  /// The `region` hint is no ISO 3166-1 alpha-2 code, so there was nothing to resolve against.
  unknownRegion('the region hint is not an ISO 3166-1 alpha-2 code'),

  /// No country calling code was recognised at the start, and no `region` supplied one.
  unknownCountryCallingCode('no country calling code recognised at the start'),

  /// The digits don't form a real number: there are none, too many, or they don't fit the country.
  invalid('not a valid number for its country');

  @override
  String get typeName => 'PhoneNumber';
}
