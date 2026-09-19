import 'package:collection/collection.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' as phone_numbers;

import 'failures/phone_number_failure.dart';

/// A phone number, stored in canonical E.164 form by `phone_numbers_parser`.
/// Standard: [E.164](https://en.wikipedia.org/wiki/E.164).
///
/// Parsing resolves to E.164 (`+`, country calling code, national number), so [value] is comparable
/// and storable. National-format input needs a [tryParse] `region` hint, ISO 3166-1 alpha-2 like `'GB'`.
/// Already-international input parses without one.
///
/// {@example /example/minted_contact_example.dart#phone}
extension type const PhoneNumber._(String value) {
  /// Builds a [PhoneNumber] from its [countryCode] (the calling code without `+`, so `44`) and its [nationalNumber]
  /// digits.
  static ParseOutcome<PhoneNumberFailure, PhoneNumber> fromComponents({
    required String countryCode,
    required Digits nationalNumber,
  }) => parse('+$countryCode${nationalNumber.asString}');

  /// Parses [input], or `null` if it isn't a valid number or [region] names no country.
  ///
  /// Pass [region] (ISO 3166-1 alpha-2) to resolve national-format input. International input needs
  /// none.
  static PhoneNumber? tryParse(String input, {String? region}) =>
      parse(input, region: region).getOrNull();

  /// Parses [input], reporting the [PhoneNumberFailure] that says what went wrong. See [tryParse] for
  /// the `region` hint.
  static ParseOutcome<PhoneNumberFailure, PhoneNumber> parse(String input, {String? region}) {
    // Resolved here rather than through the shared country check: that one answers a bool, and the engine
    // wants one of its own enum values handed back.
    final upperRegion = region?.toUpperCase();
    final callerCountry = upperRegion == null
        ? null
        : phone_numbers.IsoCode.values.firstWhereOrNull((code) => code.name == upperRegion);
    if (region != null && callerCountry == null) return const ParseFailure(.unknownRegion);

    final phone_numbers.PhoneNumber parsed;
    try {
      parsed = phone_numbers.PhoneNumber.parse(input, callerCountry: callerCountry);
    } on phone_numbers.PhoneNumberException catch (exception) {
      return ParseFailure(_failureForCode(exception.code));
    }

    return !parsed.isValid()
        ? const ParseFailure(.invalid)
        : ParseSuccess(._(parsed.international));
  }

  /// The country calling code, without the `+`, so `44` for the UK.
  String get countryCode => _parsed.countryCode;

  /// The national significant number, without the country calling code. What you'd dial within the country.
  // A validated number's national significant number is digits only, so this cannot be null.
  Digits get nationalNumber => Digits.tryFrom(decimalValues(_parsed.nsn))!;

  /// The number's type (mobile, fixed line, VoIP and so on), or `null` if it matches none. A number
  /// valid as several gives the first in declaration order.
  phone_numbers.PhoneNumberType? get type {
    final parsedPhone = _parsed;

    return phone_numbers.PhoneNumberType.values.firstWhereOrNull(
      (candidate) => parsedPhone.isValid(type: candidate),
    );
  }

  /// The national significant number grouped the country's way, `(202) 555-0119`, without the trunk
  /// prefix.
  String formatNational() => _parsed.formatNsn();

  /// A `tel:` URI for this number, `tel:+442079460958`, per [RFC 3966](https://www.rfc-editor.org/rfc/rfc3966).
  Uri get telUri => Uri(scheme: 'tel', path: value);

  phone_numbers.PhoneNumber get _parsed => phone_numbers.PhoneNumber.parse(value);

  // notFound is the only code the engine throws here. The rest are metadata misses that resolving the
  // region against IsoCode.values already rules out, so no test can reach that arm. Enumerated anyway,
  // so a new engine code breaks the build rather than quietly mapping to `invalid`.
  static PhoneNumberFailure _failureForCode(phone_numbers.Code code) => switch (code) {
    .notFound => .unknownCountryCallingCode,
    // coverage:ignore-start
    .invalid || .invalidCountryCallingCode || .invalidIsoCode || .inputIsTooLong => .invalid,
    // coverage:ignore-end
  };
}
