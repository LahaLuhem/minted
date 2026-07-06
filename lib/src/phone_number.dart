import 'package:collection/collection.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' as phone_numbers;

import 'shared/minted_format_exception.dart';

/// A phone number, validated and stored in its canonical E.164 form (via `phone_numbers_parser`).
/// Standard: [E.164](https://en.wikipedia.org/wiki/E.164).
///
/// Normalisation on parse: the number is resolved to E.164 (`+`, country calling code, national number),
/// so [value] is comparable and storable. National-format input needs a [tryParse] `region` hint
/// (ISO 3166-1 alpha-2, e.g. `'GB'`); already-international input (`+…`) parses without one.
extension type const PhoneNumber._(String value) {
  /// Parses [input] as a phone number, or returns `null` when it is not a valid number.
  ///
  /// Pass [region] (ISO 3166-1 alpha-2) to resolve national-format input; `+`-international input needs none.
  /// An unknown [region] yields `null`.
  static PhoneNumber? tryParse(String input, {String? region}) {
    final callerCountry = region == null ? null : _isoCodeForRegion(region);
    if (region != null && callerCountry == null) return null;

    final phone_numbers.PhoneNumber parsed;
    try {
      parsed = phone_numbers.PhoneNumber.parse(input, callerCountry: callerCountry);
    } on phone_numbers.PhoneNumberException {
      return null;
    }
    if (!parsed.isValid()) return null;

    return PhoneNumber._(parsed.international);
  }

  /// Parses [input] as a phone number, throwing [MintedFormatException] when it is not valid.
  /// See [tryParse] for the `region` hint.
  static PhoneNumber parse(String input, {String? region}) =>
      tryParse(input, region: region) ??
      (throw MintedFormatException.of<PhoneNumber>(input, 'not a valid phone number'));

  /// The country calling code, without the `+` (for example `44` for the UK).
  String get countryCode => _parsed.countryCode;

  /// The national (significant) number, without the country calling code.
  String get nationalNumber => _parsed.nsn;

  /// The number's type (mobile, fixed line, VoIP, ...), or `null` if it matches no known type.
  /// When a number is valid as more than one type, the first match in enum-declaration order is returned.
  phone_numbers.PhoneNumberType? get type {
    final parsed = _parsed;

    return phone_numbers.PhoneNumberType.values.firstWhereOrNull(
      (candidate) => parsed.isValid(type: candidate),
    );
  }

  /// The number formatted for national display (for example `020 7946 0958`).
  String formatNational() => _parsed.formatNsn();

  /// A `tel:` URI for this number, per
  /// [RFC 3966](https://www.rfc-editor.org/rfc/rfc3966) (for example `tel:+442079460958`).
  Uri get telUri => Uri(scheme: 'tel', path: value);

  phone_numbers.PhoneNumber get _parsed => phone_numbers.PhoneNumber.parse(value);
}

phone_numbers.IsoCode? _isoCodeForRegion(String region) {
  final upperRegion = region.toUpperCase();

  return phone_numbers.IsoCode.values.firstWhereOrNull((code) => code.name == upperRegion);
}
