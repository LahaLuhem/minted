// Data-carrying failures are built without `const` on purpose: const canonicalisation would make
// the twin identical to the original, so `==` would ride on identity instead of doing any work.
// ignore_for_file: prefer_const_constructors

import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import 'support/bdd.dart';

void main() {
  feature('the failure contract', () {
    // Every failure the package can report. A variant missing here is one nothing pins the wording
    // of, and the message is what reaches a log or a fallback UI.
    final rendering = <String, ({MintedFailure failure, String typeName, String message})>{
      'Digit has one way to fail': (
        failure: DigitFailure.notADigit,
        typeName: 'Digit',
        message: 'not a decimal digit 0-9',
      ),
      'Digits has one way to fail': (
        failure: DigitsFailure.notAllDigits,
        typeName: 'Digits',
        message: 'not all decimal digits 0-9',
      ),
      'Month has one way to fail': (
        failure: MonthFailure.notAMonth,
        typeName: 'Month',
        message: 'not a month number 1-12',
      ),
      'Weekday has one way to fail': (
        failure: WeekdayFailure.notAWeekday,
        typeName: 'Weekday',
        message: 'not a weekday number 1-7',
      ),
      'Email is capped at one by its engine': (
        failure: EmailFailure.malformed,
        typeName: 'Email',
        message: 'not a well-formed email address',
      ),
      'PhoneNumber: the region hint was not an ISO code': (
        failure: PhoneNumberFailure.unknownRegion,
        typeName: 'PhoneNumber',
        message: 'the region hint is not an ISO 3166-1 alpha-2 code',
      ),
      'PhoneNumber: no calling code found': (
        failure: PhoneNumberFailure.unknownCountryCallingCode,
        typeName: 'PhoneNumber',
        message: 'no country calling code recognised at the start',
      ),
      'PhoneNumber: not a number for its country': (
        failure: PhoneNumberFailure.invalid,
        typeName: 'PhoneNumber',
        message: 'not a valid number for its country',
      ),
      'Uuid: unrecognisable text': (
        failure: UuidMalformed(),
        typeName: 'Uuid',
        message: 'not a well-formed UUID (expected 8-4-4-4-12 hex)',
      ),
      'Uuid: wrong byte count reports both counts': (
        failure: UuidWrongByteCount(expected: 16, actual: 15),
        typeName: 'Uuid',
        message: 'expected 16 bytes, got 15',
      ),
      'Imei: not the one length': (
        failure: ImeiWrongLength(14),
        typeName: 'Imei',
        message: 'expected 15 digits, got 14',
      ),
      'Imei: sixteen digits is named as an IMEISV, not called a miscount': (
        failure: ImeiWrongLength(16),
        typeName: 'Imei',
        message: '16 digits is an IMEISV, not an IMEI',
      ),
      'Imei: bad charset': (
        failure: ImeiInvalidCharacters(),
        typeName: 'Imei',
        message: 'contains characters outside 0-9',
      ),
      'Imei: the Luhn check is named': (
        failure: ImeiChecksumFailed(),
        typeName: 'Imei',
        message: 'failed the Luhn check',
      ),
      'Isbn: neither generation has that length': (
        failure: IsbnWrongLength(12),
        typeName: 'Isbn',
        message: 'expected 10 or 13 digits, got 12',
      ),
      'Isbn: the charset message says where X is allowed': (
        failure: IsbnInvalidCharacters(),
        typeName: 'Isbn',
        message: 'contains characters outside 0-9 (X only as the ISBN-10 check digit)',
      ),
      'Isbn: an unknown prefix echoes the code': (
        failure: IsbnInvalidPrefix('977'),
        typeName: 'Isbn',
        message: '"977" is not an ISBN prefix (expected 978 or 979)',
      ),
      'Isbn: the ISMN range is named, not called a typo': (
        failure: IsbnInvalidPrefix('9790'),
        typeName: 'Isbn',
        message: '"9790" is the ISMN range for printed music, not an ISBN',
      ),
      'Isbn: checksum failed': (
        failure: IsbnChecksumFailed(),
        typeName: 'Isbn',
        message: 'failed the check-digit test',
      ),
      'Gtin: none of the four GS1 lengths': (
        failure: GtinWrongLength(9),
        typeName: 'Gtin',
        message: 'expected 8, 12, 13 or 14 digits, got 9',
      ),
      'Gtin: bad charset': (
        failure: GtinInvalidCharacters(),
        typeName: 'Gtin',
        message: 'contains characters outside 0-9',
      ),
      'Gtin: the GS1 check is named': (
        failure: GtinChecksumFailed(),
        typeName: 'Gtin',
        message: 'failed the GS1 mod-10 check',
      ),
      'Date: wrong shape': (
        failure: DateNotIso8601(),
        typeName: 'Date',
        message: 'not an ISO 8601 YYYY-MM-DD calendar date',
      ),
      'Date: year out of range': (
        failure: DateYearOutOfRange(10000),
        typeName: 'Date',
        message: 'year 10000 is outside 0000-9999',
      ),
      'Date: month out of range': (
        failure: DateMonthOutOfRange(13),
        typeName: 'Date',
        message: 'month 13 is outside 1-12',
      ),
      'Date: day out of range names the leap-aware bound': (
        failure: DateDayOutOfRange(year: 2026, month: 2, day: 30, maxDay: 28),
        typeName: 'Date',
        message: 'day 30 is outside 1-28 for 2026-02',
      ),
      'Iban: too short to identify a country': (
        failure: IbanTooShort(),
        typeName: 'Iban',
        message: 'too short to identify a country',
      ),
      'Iban: bad charset': (
        failure: IbanInvalidCharacters(),
        typeName: 'Iban',
        message: 'contains characters outside A-Z and 0-9',
      ),
      'Iban: unknown country echoes the code': (
        failure: IbanUnknownCountry('ZZ'),
        typeName: 'Iban',
        message: '"ZZ" is not a recognised country code',
      ),
      'Iban: wrong length names the expected one': (
        failure: IbanInvalidLength(expected: 22, actual: 21),
        typeName: 'Iban',
        message: 'expected 22 characters for this country, got 21',
      ),
      'Iban: checksum failed': (
        failure: IbanChecksumFailed(),
        typeName: 'Iban',
        message: 'failed the mod-97 check',
      ),
      'Bic: neither of the two lengths': (
        failure: BicWrongLength(9),
        typeName: 'Bic',
        message: 'expected 8 or 11 characters, got 9',
      ),
      'Bic: bad charset': (
        failure: BicInvalidCharacters(),
        typeName: 'Bic',
        message: 'contains characters outside A-Z and 0-9',
      ),
      'Bic: unknown country echoes the code': (
        failure: BicUnknownCountry('ZZ'),
        typeName: 'Bic',
        message: '"ZZ" is not a recognised country code',
      ),
      'PaymentCardNumber: outside the 8-to-19 window': (
        failure: PaymentCardNumberWrongLength(7),
        typeName: 'PaymentCardNumber',
        message: 'expected 8 to 19 digits, got 7',
      ),
      'PaymentCardNumber: bad charset': (
        failure: PaymentCardNumberInvalidCharacters(),
        typeName: 'PaymentCardNumber',
        message: 'contains characters outside 0-9',
      ),
      'PaymentCardNumber: the Luhn check is named': (
        failure: PaymentCardNumberChecksumFailed(),
        typeName: 'PaymentCardNumber',
        message: 'failed the Luhn check',
      ),
    };

    scenarioOutline<({MintedFailure failure, String typeName, String message})>(
      'every failure names its type and renders its message',
      examples: rendering,
      outline: (example) {
        check(example.failure.typeName).equals(example.typeName);
        check(example.failure.message).equals(example.message);
        // The exception derives its message from these two, so this is the rendered form too.
        check(
          MintedFormatException.from(example.failure, 'x').message,
        ).equals('Invalid ${example.typeName}: ${example.message}');
      },
    );

    scenarioOutline<({MintedFailure failure, String rendered})>(
      'every failure renders its contents, never Instance of',
      examples: {
        'a no-data variant': (failure: IbanTooShort(), rendered: 'IbanTooShort()'),
        'a variant echoing a code': (
          failure: IbanUnknownCountry('ZZ'),
          rendered: 'IbanUnknownCountry(ZZ)',
        ),
        'a variant with two counts': (
          failure: IbanInvalidLength(expected: 22, actual: 21),
          rendered: 'IbanInvalidLength(expected: 22, actual: 21)',
        ),
        'the bad-charset variant': (
          failure: IbanInvalidCharacters(),
          rendered: 'IbanInvalidCharacters()',
        ),
        'the checksum variant': (failure: IbanChecksumFailed(), rendered: 'IbanChecksumFailed()'),
        'a malformed UUID': (failure: UuidMalformed(), rendered: 'UuidMalformed()'),
        'a wrong byte count': (
          failure: UuidWrongByteCount(expected: 16, actual: 15),
          rendered: 'UuidWrongByteCount(expected: 16, actual: 15)',
        ),
        'a wrong IMEI length': (failure: ImeiWrongLength(14), rendered: 'ImeiWrongLength(14)'),
        'an IMEI charset failure': (
          failure: ImeiInvalidCharacters(),
          rendered: 'ImeiInvalidCharacters()',
        ),
        'the IMEI Luhn variant': (failure: ImeiChecksumFailed(), rendered: 'ImeiChecksumFailed()'),
        'a wrong ISBN length': (failure: IsbnWrongLength(12), rendered: 'IsbnWrongLength(12)'),
        'an ISBN charset failure': (
          failure: IsbnInvalidCharacters(),
          rendered: 'IsbnInvalidCharacters()',
        ),
        'an unknown ISBN prefix': (
          failure: IsbnInvalidPrefix('977'),
          rendered: 'IsbnInvalidPrefix(977)',
        ),
        'the ISBN checksum variant': (
          failure: IsbnChecksumFailed(),
          rendered: 'IsbnChecksumFailed()',
        ),
        'a wrong GTIN length': (failure: GtinWrongLength(9), rendered: 'GtinWrongLength(9)'),
        'a GTIN charset failure': (
          failure: GtinInvalidCharacters(),
          rendered: 'GtinInvalidCharacters()',
        ),
        'the GTIN checksum variant': (
          failure: GtinChecksumFailed(),
          rendered: 'GtinChecksumFailed()',
        ),
        'a wrong-shaped date': (failure: DateNotIso8601(), rendered: 'DateNotIso8601()'),
        'a bad year': (failure: DateYearOutOfRange(10000), rendered: 'DateYearOutOfRange(10000)'),
        'a bad month': (failure: DateMonthOutOfRange(13), rendered: 'DateMonthOutOfRange(13)'),
        'a bad day': (
          failure: DateDayOutOfRange(year: 2026, month: 2, day: 30, maxDay: 28),
          rendered: 'DateDayOutOfRange(year: 2026, month: 2, day: 30, maxDay: 28)',
        ),
        'a wrong BIC length': (failure: BicWrongLength(9), rendered: 'BicWrongLength(9)'),
        'a BIC charset failure': (
          failure: BicInvalidCharacters(),
          rendered: 'BicInvalidCharacters()',
        ),
        'an unknown BIC country': (
          failure: BicUnknownCountry('ZZ'),
          rendered: 'BicUnknownCountry(ZZ)',
        ),
        'a wrong card-number length': (
          failure: PaymentCardNumberWrongLength(7),
          rendered: 'PaymentCardNumberWrongLength(7)',
        ),
        'a card-number charset failure': (
          failure: PaymentCardNumberInvalidCharacters(),
          rendered: 'PaymentCardNumberInvalidCharacters()',
        ),
        'the Luhn variant': (
          failure: PaymentCardNumberChecksumFailed(),
          rendered: 'PaymentCardNumberChecksumFailed()',
        ),
      },
      outline: (example) => check(example.failure.toString()).equals(example.rendered),
    );

    // A separately-built twin, and a near-miss that differs in exactly one field, so an `==` that
    // compared only the type (or forgot a field) would fail here.
    scenarioOutline<({MintedFailure failure, MintedFailure twin, MintedFailure other})>(
      'failures are equal by value, hash with their equals, and reject near-misses',
      examples: {
        'no-data variants compare by type': (
          failure: IbanTooShort(),
          twin: IbanTooShort(),
          other: IbanInvalidCharacters(),
        ),
        'the checksum variant': (
          failure: IbanChecksumFailed(),
          twin: IbanChecksumFailed(),
          other: IbanTooShort(),
        ),
        'the bad-charset variant': (
          failure: IbanInvalidCharacters(),
          twin: IbanInvalidCharacters(),
          other: IbanChecksumFailed(),
        ),
        'unknown country differs by its code': (
          failure: IbanUnknownCountry('ZZ'),
          twin: IbanUnknownCountry('ZZ'),
          other: IbanUnknownCountry('XX'),
        ),
        'invalid length differs by one count': (
          failure: IbanInvalidLength(expected: 22, actual: 21),
          twin: IbanInvalidLength(expected: 22, actual: 21),
          other: IbanInvalidLength(expected: 22, actual: 20),
        ),
        'a malformed UUID': (
          failure: UuidMalformed(),
          twin: UuidMalformed(),
          other: UuidWrongByteCount(expected: 16, actual: 15),
        ),
        'byte count differs by its actual': (
          failure: UuidWrongByteCount(expected: 16, actual: 15),
          twin: UuidWrongByteCount(expected: 16, actual: 15),
          other: UuidWrongByteCount(expected: 16, actual: 17),
        ),
        'IMEI length differs by its count': (
          failure: ImeiWrongLength(14),
          twin: ImeiWrongLength(14),
          other: ImeiWrongLength(16),
        ),
        'the IMEI charset variant': (
          failure: ImeiInvalidCharacters(),
          twin: ImeiInvalidCharacters(),
          other: ImeiChecksumFailed(),
        ),
        'the IMEI Luhn variant': (
          failure: ImeiChecksumFailed(),
          twin: ImeiChecksumFailed(),
          other: ImeiInvalidCharacters(),
        ),
        'ISBN length differs by its count': (
          failure: IsbnWrongLength(12),
          twin: IsbnWrongLength(12),
          other: IsbnWrongLength(14),
        ),
        'the ISBN charset variant': (
          failure: IsbnInvalidCharacters(),
          twin: IsbnInvalidCharacters(),
          other: IsbnChecksumFailed(),
        ),
        'an ISBN prefix differs by its code': (
          failure: IsbnInvalidPrefix('977'),
          twin: IsbnInvalidPrefix('977'),
          other: IsbnInvalidPrefix('9790'),
        ),
        'the ISBN checksum variant': (
          failure: IsbnChecksumFailed(),
          twin: IsbnChecksumFailed(),
          other: IsbnInvalidCharacters(),
        ),
        'GTIN length differs by its count': (
          failure: GtinWrongLength(9),
          twin: GtinWrongLength(9),
          other: GtinWrongLength(15),
        ),
        'the GTIN charset variant': (
          failure: GtinInvalidCharacters(),
          twin: GtinInvalidCharacters(),
          other: GtinChecksumFailed(),
        ),
        'the GTIN checksum variant': (
          failure: GtinChecksumFailed(),
          twin: GtinChecksumFailed(),
          other: GtinInvalidCharacters(),
        ),
        'a wrong-shaped date': (
          failure: DateNotIso8601(),
          twin: DateNotIso8601(),
          other: DateYearOutOfRange(10000),
        ),
        'year differs by its value': (
          failure: DateYearOutOfRange(10000),
          twin: DateYearOutOfRange(10000),
          other: DateYearOutOfRange(-1),
        ),
        'month differs by its value': (
          failure: DateMonthOutOfRange(13),
          twin: DateMonthOutOfRange(13),
          other: DateMonthOutOfRange(0),
        ),
        'day differs only by its leap-aware bound': (
          failure: DateDayOutOfRange(year: 2026, month: 2, day: 30, maxDay: 28),
          twin: DateDayOutOfRange(year: 2026, month: 2, day: 30, maxDay: 28),
          other: DateDayOutOfRange(year: 2024, month: 2, day: 30, maxDay: 29),
        ),
        'BIC length differs by its count': (
          failure: BicWrongLength(9),
          twin: BicWrongLength(9),
          other: BicWrongLength(10),
        ),
        'the BIC charset variant': (
          failure: BicInvalidCharacters(),
          twin: BicInvalidCharacters(),
          other: BicWrongLength(9),
        ),
        'a BIC country differs by its code': (
          failure: BicUnknownCountry('ZZ'),
          twin: BicUnknownCountry('ZZ'),
          other: BicUnknownCountry('QQ'),
        ),
        'a card-number length differs by its count': (
          failure: PaymentCardNumberWrongLength(7),
          twin: PaymentCardNumberWrongLength(7),
          other: PaymentCardNumberWrongLength(20),
        ),
        'the card-number charset variant': (
          failure: PaymentCardNumberInvalidCharacters(),
          twin: PaymentCardNumberInvalidCharacters(),
          other: PaymentCardNumberChecksumFailed(),
        ),
        'the Luhn variant': (
          failure: PaymentCardNumberChecksumFailed(),
          twin: PaymentCardNumberChecksumFailed(),
          other: PaymentCardNumberInvalidCharacters(),
        ),
        'enum variants are canonical': (
          failure: PhoneNumberFailure.invalid,
          twin: PhoneNumberFailure.invalid,
          other: PhoneNumberFailure.unknownRegion,
        ),
      },
      outline: (example) {
        check(example.failure).equals(example.twin);
        check(example.failure.hashCode).equals(example.twin.hashCode);
        check(example.failure == example.other).isFalse();
      },
    );
  });
}
