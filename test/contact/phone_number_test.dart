import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('PhoneNumber', () {
    // A String canonical means "accepted and normalised to this E.164"; null
    // means "rejected". National-format input resolves only with a region.
    scenarioOutline<({String input, String? region, String? canonical})>(
      'PhoneNumber.tryParse resolves valid numbers to E.164 and rejects the rest',
      examples: {
        'international form, no region needed': (
          input: '+33 655 5705 76',
          region: null,
          canonical: '+33655570576',
        ),
        'national form with a region': (
          input: '0 655 5705 76',
          region: 'FR',
          canonical: '+33655570576',
        ),
        'national form without a region': (input: '0 655 5705 76', region: null, canonical: null),
        'an unknown region': (input: '0 655 5705 76', region: 'XX', canonical: null),
        'not a number at all': (input: 'not-a-number', region: null, canonical: null),
        'empty': (input: '', region: null, canonical: null),
      },
      outline: (example) {
        final parsedPhone = PhoneNumber.tryParse(example.input, region: example.region);

        check(parsedPhone?.value).equals(example.canonical);
      },
    );

    scenario('international and national forms of the same number are equal', () {
      check(PhoneNumber.tryParse('+33 655 5705 76')!)
          .equals(PhoneNumber.tryParse('0 655 5705 76', region: 'FR')!);
    });

    scenario('a phone number exposes its country calling code and national number', () {
      final parsedPhone = PhoneNumber.tryParse('+33 655 5705 76')!;

      check(parsedPhone.countryCode).equals('33');
      check(parsedPhone.nationalNumber.length).equals(9);
      check(parsedPhone.nationalNumber.first).equals(Digit.tryFrom(6)!);
      check(parsedPhone.nationalNumber.asString).equals('655570576');
    });

    scenario('a French mobile is classified as mobile', () {
      check(PhoneNumber.tryParse('+33 655 5705 76')!.type).equals(PhoneNumberType.mobile);
    });

    scenario('a phone number builds a tel: URI', () {
      check(PhoneNumber.tryParse('+33 655 5705 76')!.telUri.toString()).equals('tel:+33655570576');
    });

    // Only unknownCountryCallingCode comes from the engine: notFound is the one code
    // phone_numbers_parser actually throws, and everything else arrives as isValid() == false.
    scenarioOutline<({String input, String? region, PhoneNumberFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'a region hint that is not an ISO code': (
          input: '0655570576',
          region: 'ZZ',
          failure: PhoneNumberFailure.unknownRegion,
        ),
        'text with no calling code to find': (
          input: 'not-a-number',
          region: null,
          failure: PhoneNumberFailure.unknownCountryCallingCode,
        ),
        'national format with no region to resolve it': (
          input: '0655570576',
          region: null,
          failure: PhoneNumberFailure.unknownCountryCallingCode,
        ),
        'an unassigned calling code': (
          input: '+99912345678',
          region: null,
          failure: PhoneNumberFailure.unknownCountryCallingCode,
        ),
        'a known country but too few digits': (
          input: '+44123',
          region: null,
          failure: PhoneNumberFailure.invalid,
        ),
        'letters where the region is known': (
          input: 'abcdef',
          region: 'GB',
          failure: PhoneNumberFailure.invalid,
        ),
      },
      outline: (example) =>
          check(PhoneNumber.parse(example.input, region: example.region).reasonOrNull)
              .equals(example.failure),
    );

    scenario('an unknown region is distinguished from an unparseable number', () {
      check(PhoneNumber.parse('0655570576', region: 'ZZ').reasonOrNull?.message)
          .equals('the region hint is not an ISO 3166-1 alpha-2 code');
    });

    scenario('parse reports the failure rather than throwing', () {
      check(PhoneNumber.parse('not-a-number'))
          .equals(const ParseFailure(PhoneNumberFailure.unknownCountryCallingCode));
      check(PhoneNumber.parse('+33 655 5705 76').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(PhoneNumber.tryParse('not-a-number')).isNull();
      check(PhoneNumber.tryParse('+33 655 5705 76')?.value).equals('+33655570576');
    });

    scenario('fromComponents assembles the E.164 form from calling code and number', () {
      check(
        PhoneNumber.fromComponents(
          countryCode: '33',
          nationalNumber: Digits.tryFrom([6, 5, 5, 5, 7, 0, 5, 7, 6])!,
        ).getOrThrow().value,
      ).equals('+33655570576');
    });

    scenario('fromComponents reports a failure on an invalid number, and never throws', () {
      check(
        PhoneNumber.fromComponents(
          countryCode: '33',
          nationalNumber: Digits.tryFrom([1])!,
        ).reasonOrNull,
      ).equals(PhoneNumberFailure.invalid);
    });

    scenario('the region hint is case-insensitive', () {
      check(PhoneNumber.tryParse('0 655 5705 76', region: 'fr')?.value).equals('+33655570576');
    });

    scenario('type finds a non-mobile classification', () {
      check(PhoneNumber.tryParse('+33 1 42 68 53 00')!.type).equals(PhoneNumberType.fixedLine);
    });

    scenario('formatNational renders the local display form', () {
      check(PhoneNumber.tryParse('+33 6 55 57 05 76')!.formatNational()).equals('6 55 57 05 76');
    });

    scenario('a caller who asserts the parts gets the throw back through getOrThrow', () {
      check(
            () => PhoneNumber.fromComponents(
              countryCode: '33',
              nationalNumber: Digits.tryFrom([1])!,
            ).getOrThrow(),
          )
          .throws<MintedFormatError>()
          .has((error) => error.failure, 'failure')
          .equals(PhoneNumberFailure.invalid);
    });
  });
}
