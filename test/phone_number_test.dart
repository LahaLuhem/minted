import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import 'support/bdd.dart';

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
      check(
        PhoneNumber.parse('+33 655 5705 76'),
      ).equals(PhoneNumber.parse('0 655 5705 76', region: 'FR'));
    });

    scenario('a phone number exposes its country calling code and national number', () {
      final parsedPhone = PhoneNumber.parse('+33 655 5705 76');

      check(parsedPhone.countryCode).equals('33');
      check(parsedPhone.nationalNumber.length).equals(9);
      check(parsedPhone.nationalNumber.first).equals(Digit.from(6));
      check(parsedPhone.nationalNumber.asString).equals('655570576');
    });

    scenario('a French mobile is classified as mobile', () {
      check(PhoneNumber.parse('+33 655 5705 76').type).equals(PhoneNumberType.mobile);
    });

    scenario('a phone number builds a tel: URI', () {
      check(PhoneNumber.parse('+33 655 5705 76').telUri.toString()).equals('tel:+33655570576');
    });

    scenario('PhoneNumber.parse throws MintedFormatException on invalid input', () {
      check(() => PhoneNumber.parse('not-a-number')).throws<MintedFormatException>();
    });

    scenario('fromComponents assembles the E.164 form from calling code and number', () {
      check(
        PhoneNumber.fromComponents(
          countryCode: '33',
          nationalNumber: Digits.parse('655570576'),
        ).value,
      ).equals('+33655570576');
    });

    scenario('fromComponents throws MintedFormatException on an invalid number', () {
      check(
        () => PhoneNumber.fromComponents(countryCode: '33', nationalNumber: Digits.parse('1')),
      ).throws<MintedFormatException>();
    });

    scenario('the region hint is case-insensitive', () {
      check(PhoneNumber.tryParse('0 655 5705 76', region: 'fr')?.value).equals('+33655570576');
    });

    scenario('type finds a non-mobile classification', () {
      check(PhoneNumber.parse('+33 1 42 68 53 00').type).equals(PhoneNumberType.fixedLine);
    });

    scenario('formatNational renders the local display form', () {
      check(PhoneNumber.parse('+33 6 55 57 05 76').formatNational()).equals('6 55 57 05 76');
    });

    scenario('parse error carries the offending input as its source', () {
      check(() => PhoneNumber.parse('nope'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('nope');
    });
  });
}
