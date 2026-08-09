import 'package:collection/collection.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' as phone_numbers;

import '../numerics/digits.dart';
import '../shared/minted_format_exception.dart';
import 'failures/phone_number_failure.dart';

/// A phone number, validated and stored in its canonical E.164 form (via `phone_numbers_parser`).
/// Standard: [E.164](https://en.wikipedia.org/wiki/E.164).
///
/// Normalisation on parse: the number is resolved to E.164 (`+`, country calling code, national number),
/// so [value] is comparable and storable. National-format input needs a [tryParse] `region` hint
/// (ISO 3166-1 alpha-2, e.g. `'GB'`); already-international input (`+…`) parses without one.
extension type const PhoneNumber._(String value) {
  /// Builds a [PhoneNumber] from its [countryCode] (the calling code without
  /// `+`, e.g. `44`) and its [nationalNumber] digits. Throws
  /// [MintedFormatException] if they don't form a valid number. For assembling
  /// from a known-valid source.
  static PhoneNumber fromComponents({
    required String countryCode,
    required Digits nationalNumber,
  }) => parse('+$countryCode${nationalNumber.asString}');

  /// Parses [input] as a phone number, or returns `null` when it is not a valid number.
  ///
  /// Pass [region] (ISO 3166-1 alpha-2) to resolve national-format input; `+`-international input needs none.
  /// An unknown [region] yields `null`.
  static PhoneNumber? tryParse(String input, {String? region}) {
    final e164 = _resolve(input, region).e164;

    return e164 == null ? null : ._(e164);
  }

  /// Parses [input] as a phone number, throwing [MintedFormatException] carrying the
  /// [PhoneNumberFailure] that says which check failed. See [tryParse] for the `region` hint.
  static PhoneNumber parse(String input, {String? region}) {
    final (:e164, :failure) = _resolve(input, region);

    return failure != null ? throw MintedFormatException.from(failure, input) : ._(e164!);
  }

  /// The country calling code, without the `+` (for example `44` for the UK).
  String get countryCode => _parsed.countryCode;

  /// The national (significant) number as a [Digits] sequence, without the
  /// country calling code (the local number you'd dial within the country).
  /// Use [Digits.asString] for the plain string.
  Digits get nationalNumber => Digits.parse(_parsed.nsn);

  /// The number's type (mobile, fixed line, VoIP, ...), or `null` if it matches no known type.
  /// When a number is valid as more than one type, the first match in enum-declaration order is returned.
  phone_numbers.PhoneNumberType? get type {
    final parsed = _parsed;

    return phone_numbers.PhoneNumberType.values.firstWhereOrNull(
      (candidate) => parsed.isValid(type: candidate),
    );
  }

  /// The national significant number, grouped for display per the country's
  /// convention (for example `(202) 555-0119`), without the trunk prefix.
  String formatNational() => _parsed.formatNsn();

  /// A `tel:` URI for this number, per
  /// [RFC 3966](https://www.rfc-editor.org/rfc/rfc3966) (for example `tel:+442079460958`).
  Uri get telUri => Uri(scheme: 'tel', path: value);

  phone_numbers.PhoneNumber get _parsed => phone_numbers.PhoneNumber.parse(value);

  // The E.164 form of [input], or why it is not a phone number; exactly one field is non-null. The
  // single gate tryParse and parse funnel through, so a diagnosis and an acceptance can't disagree.
  static ({String? e164, PhoneNumberFailure? failure}) _resolve(String input, String? region) {
    final callerCountry = region == null ? null : _isoCodeForRegion(region);
    if (region != null && callerCountry == null) {
      return (e164: null, failure: PhoneNumberFailure.unknownRegion);
    }

    final phone_numbers.PhoneNumber parsed;
    try {
      parsed = phone_numbers.PhoneNumber.parse(input, callerCountry: callerCountry);
    } on phone_numbers.PhoneNumberException catch (exception) {
      return (e164: null, failure: _failureForCode(exception.code));
    }

    return parsed.isValid()
        ? (e164: parsed.international, failure: null)
        : (e164: null, failure: PhoneNumberFailure.invalid);
  }

  // notFound is the only code 9.0.24 throws here; the rest are engine metadata misses that
  // resolving the region against IsoCode.values already rules out.
  static PhoneNumberFailure _failureForCode(phone_numbers.Code code) => switch (code) {
    .notFound => .unknownCountryCallingCode,
    .invalid || .invalidCountryCallingCode || .invalidIsoCode || .inputIsTooLong => .invalid,
  };
}

phone_numbers.IsoCode? _isoCodeForRegion(String region) {
  final upperRegion = region.toUpperCase();

  return phone_numbers.IsoCode.values.firstWhereOrNull((code) => code.name == upperRegion);
}
