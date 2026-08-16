import 'package:collection/collection.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' as phone_numbers;

import 'failures/phone_number_failure.dart';

/// A phone number, validated and stored in its canonical E.164 form (via `phone_numbers_parser`).
/// Standard: [E.164](https://en.wikipedia.org/wiki/E.164).
///
/// Normalisation on parse: the number is resolved to E.164 (`+`, country calling code, national number),
/// so [value] is comparable and storable. National-format input needs a [tryParse] `region` hint
/// (ISO 3166-1 alpha-2, e.g. `'GB'`); already-international input (`+…`) parses without one.
///
/// {@example /example/minted_contact_example.dart#phone}
extension type const PhoneNumber._(String value) {
  /// Builds a [PhoneNumber] from its [countryCode] (the calling code without `+`, e.g. `44`) and its
  /// [nationalNumber] digits, reporting the [PhoneNumberFailure] when they don't form a valid number.
  static ParseOutcome<PhoneNumberFailure, PhoneNumber> fromComponents({
    required String countryCode,
    required Digits nationalNumber,
  }) => parse('+$countryCode${nationalNumber.asString}');

  /// Parses [input] as a phone number, or returns `null` when it is not a valid number.
  ///
  /// Pass [region] (ISO 3166-1 alpha-2) to resolve national-format input; `+`-international input needs none.
  /// An unknown [region] yields `null`.
  static PhoneNumber? tryParse(String input, {String? region}) =>
      parse(input, region: region).getOrNull();

  /// Parses [input] as a phone number, reporting the [PhoneNumberFailure] that says which check
  /// failed. See [tryParse] for the `region` hint.
  static ParseOutcome<PhoneNumberFailure, PhoneNumber> parse(String input, {String? region}) {
    // Resolved here rather than through the shared country check: that one answers a bool, and the
    // engine wants one of its own enum values handed back.
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

  /// The country calling code, without the `+` (for example `44` for the UK).
  String get countryCode => _parsed.countryCode;

  /// The national (significant) number as a [Digits] sequence, without the
  /// country calling code (the local number you'd dial within the country).
  /// Use [Digits.asString] for the plain string.
  // A validated number's national significant number is digits only, so this cannot be null.
  Digits get nationalNumber => Digits.tryFrom(decimalValues(_parsed.nsn))!;

  /// The number's type (mobile, fixed line, VoIP, ...), or `null` if it matches no known type.
  /// When a number is valid as more than one type, the first match in enum-declaration order is returned.
  phone_numbers.PhoneNumberType? get type {
    final parsedPhone = _parsed;

    return phone_numbers.PhoneNumberType.values.firstWhereOrNull(
      (candidate) => parsedPhone.isValid(type: candidate),
    );
  }

  /// The national significant number, grouped for display per the country's
  /// convention (for example `(202) 555-0119`), without the trunk prefix.
  String formatNational() => _parsed.formatNsn();

  /// A `tel:` URI for this number, per
  /// [RFC 3966](https://www.rfc-editor.org/rfc/rfc3966) (for example `tel:+442079460958`).
  Uri get telUri => Uri(scheme: 'tel', path: value);

  phone_numbers.PhoneNumber get _parsed => phone_numbers.PhoneNumber.parse(value);

  // notFound is the only code 9.0.24 throws here; the rest are engine metadata misses that
  // resolving the region against IsoCode.values already rules out, so no test can reach that arm.
  // It stays enumerated so a new engine code breaks the build rather than silently mapping to
  // `invalid`.
  static PhoneNumberFailure _failureForCode(phone_numbers.Code code) => switch (code) {
    .notFound => .unknownCountryCallingCode,
    // coverage:ignore-start
    .invalid || .invalidCountryCallingCode || .invalidIsoCode || .inputIsTooLong => .invalid,
    // coverage:ignore-end
  };
}
