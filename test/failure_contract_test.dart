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
        'a wrong-shaped date': (failure: DateNotIso8601(), rendered: 'DateNotIso8601()'),
        'a bad year': (failure: DateYearOutOfRange(10000), rendered: 'DateYearOutOfRange(10000)'),
        'a bad month': (failure: DateMonthOutOfRange(13), rendered: 'DateMonthOutOfRange(13)'),
        'a bad day': (
          failure: DateDayOutOfRange(year: 2026, month: 2, day: 30, maxDay: 28),
          rendered: 'DateDayOutOfRange(year: 2026, month: 2, day: 30, maxDay: 28)',
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
