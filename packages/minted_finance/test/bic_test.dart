import 'package:checks/checks.dart';
import 'package:minted/minted.dart';
import 'package:minted_finance/minted_finance.dart';

import 'support/bdd.dart';

void main() {
  feature('Bic', () {
    // The canonical eleven-character form doubles as the expected outcome: a String means "accepted
    // and normalised to this", null means "rejected". Valid rows are published bank codes.
    scenarioOutline<({String input, String? canonical})>(
      'Bic.tryParse normalises accepted input and rejects input that fails a check',
      examples: {
        'an eight-character BIC gains the primary-office branch': (
          input: 'DEUTDEFF',
          canonical: 'DEUTDEFFXXX',
        ),
        'an eleven-character BIC keeps its branch': (
          input: 'DEUTDEFF500',
          canonical: 'DEUTDEFF500',
        ),
        'a branch already spelled XXX is left alone': (
          input: 'BNPAFRPPXXX',
          canonical: 'BNPAFRPPXXX',
        ),
        'a digit in the location code': (input: 'CHASUS33', canonical: 'CHASUS33XXX'),
        'digits in both the location and branch codes': (
          input: 'RZTIAT22263',
          canonical: 'RZTIAT22263',
        ),
        'a mixed letter-digit location code': (input: 'HBUKGB4B', canonical: 'HBUKGB4BXXX'),
        'lower case is folded up': (input: 'nedszajj', canonical: 'NEDSZAJJXXX'),
        'BICs are read aloud in groups, so spaces arrive with them': (
          input: 'UNCR IT MM',
          canonical: 'UNCRITMMXXX',
        ),
        'ISO 9362 allows the digits in a prefix that SWIFT does not issue': (
          input: 'E097AEXX',
          canonical: 'E097AEXXXXX',
        ),
        'nine characters is neither length': (input: 'DEUTDEFFX', canonical: null),
        'ten characters is neither length': (input: 'DEUTDEFFXX', canonical: null),
        'seven characters is neither length': (input: 'DEUTDEF', canonical: null),
        'twelve characters is neither length': (input: 'DEUTDEFF5000', canonical: null),
        'empty': (input: '', canonical: null),
        'a separator is not a BIC character': (input: 'DEUTDEFF-XX', canonical: null),
        'ZZ is not a country': (input: 'DEUTZZFF', canonical: null),
        'digits cannot name a country either': (input: 'DEUT1EFF', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as a BIC ...
        final parsedBic = Bic.tryParse(example.input);

        // Then it is normalised to the eleven-character form, or rejected (null).
        check(parsedBic?.value).equals(example.canonical);
      },
    );

    scenario('the two spellings of one primary office are equal', () {
      check(Bic.tryParse('DEUTDEFF')!).equals(Bic.tryParse('DEUTDEFFXXX')!);
      check({Bic.tryParse('DEUTDEFF')!, Bic.tryParse('deut de ff xxx')!}).length.equals(1);
    });

    scenario('a branch BIC exposes each of its four parts', () {
      final parsedBic = Bic.tryParse('DEUTDEFF500')!;

      check(parsedBic.institutionCode).equals('DEUT');
      check(parsedBic.countryCode).equals('DE');
      check(parsedBic.locationCode).equals('FF');
      check(parsedBic.branchCode).equals('500');
      check(parsedBic.bic8).equals('DEUTDEFF');
      check(parsedBic.isPrimaryOffice).isFalse();
    });

    scenario('a folded BIC reports the branch it was given', () {
      check(Bic.tryParse('DEUTDEFF')!.branchCode).equals('XXX');
      check(Bic.tryParse('DEUTDEFF')!.isPrimaryOffice).isTrue();
    });

    // Kosovo has no ISO 3166-1 code of its own, so SWIFT registers its banks under the
    // user-assigned XK. Accepting it is the point: the alternative rejects real Kosovar BICs.
    scenario('XK is accepted, because SWIFT registers Kosovo under it', () {
      check(Bic.tryParse('TEBKXKPR')?.value).equals('TEBKXKPRXXX');
    });

    // The standard is wider than the registry, so this is a report, not a rejection. One row per
    // freedom ISO 9362 grants and SWIFT declines to use.
    scenarioOutline<({String input, bool isSwiftRegistrable})>(
      'isSwiftRegistrable reports the narrower shape SWIFT itself issues',
      examples: {
        'an ordinary registered BIC': (input: 'DEUTDEFF', isSwiftRegistrable: true),
        'a branch BIC with digits past the country code': (
          input: 'RZTIAT22263',
          isSwiftRegistrable: true,
        ),
        'digits in the institution code': (input: 'E097AEXX', isSwiftRegistrable: false),
        'a zero opening the location code': (input: 'DEUTDE0F', isSwiftRegistrable: false),
        'a one opening the location code': (input: 'DEUTDE1F', isSwiftRegistrable: false),
        'the letter O closing the location code, too easily a zero': (
          input: 'DEUTDEFO',
          isSwiftRegistrable: false,
        ),
      },
      outline: (example) {
        final parsedBic = Bic.tryParse(example.input);

        // Every row parses; only the shape report differs.
        check(parsedBic).isNotNull();
        check(parsedBic!.isSwiftRegistrable).equals(example.isSwiftRegistrable);
      },
    );

    scenarioOutline<({String input, BicFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'empty input is no length at all': (input: '', failure: const BicWrongLength(0)),
        'nine characters is neither length': (input: 'DEUTDEFFX', failure: const BicWrongLength(9)),
        // Hyphenated groupings mostly land on the length check instead, since a BIC has no
        // separator positions to spend characters on; this one keeps the count at eleven.
        'a hyphen before the branch code survives the whitespace strip': (
          input: 'DEUTDEFF-XX',
          failure: const BicInvalidCharacters(),
        ),
        'an unregistered country code': (input: 'DEUTZZFF', failure: const BicUnknownCountry('ZZ')),
        'digits in the country slot name no country': (
          input: 'DEUT1EFF',
          failure: const BicUnknownCountry('1E'),
        ),
      },
      outline: (example) => check(Bic.parse(example.input).reasonOrNull).equals(example.failure),
    );

    scenario('parse reports the failure rather than throwing', () {
      check(Bic.parse('DEUTZZFF')).equals(const ParseFailure(BicUnknownCountry('ZZ')));
      check(Bic.parse('DEUTDEFF').isSuccess).isTrue();
    });

    // The two edges a numbering-plan list gets wrong in opposite directions: AQ is ISO-assigned
    // but has no phone numbers, AC is only reserved, never assigned.
    scenario('the country check reads the ISO registry, not a numbering-plan list', () {
      check(Bic.tryParse('DEUTAQFF')?.value).equals('DEUTAQFFXXX');
      check(Bic.tryParse('DEUTACFF')).isNull();
    });

    scenarioOutline<({String locationCode, String? branchCode, String bic})>(
      'fromComponents assembles the parts, defaulting to the primary office',
      examples: {
        'no branch code folds to XXX': (locationCode: 'FF', branchCode: null, bic: 'DEUTDEFFXXX'),
        'a branch code is kept': (locationCode: 'FF', branchCode: '500', bic: 'DEUTDEFF500'),
        'a lower-case part is folded up': (
          locationCode: 'ff',
          branchCode: '500',
          bic: 'DEUTDEFF500',
        ),
      },
      outline: (example) {
        final assembledBic = example.branchCode == null
            ? Bic.fromComponents(
                institutionCode: 'DEUT',
                countryCode: 'DE',
                locationCode: example.locationCode,
              )
            : Bic.fromComponents(
                institutionCode: 'DEUT',
                countryCode: 'DE',
                locationCode: example.locationCode,
                branchCode: example.branchCode!,
              );

        check(assembledBic.getOrThrow().value).equals(example.bic);
      },
    );

    scenarioOutline<({String institutionCode, String countryCode, BicFailure failure})>(
      'fromComponents reports the same vocabulary as parse',
      examples: {
        'a short institution code cannot reach eight characters': (
          institutionCode: 'DEU',
          countryCode: 'DE',
          failure: const BicWrongLength(10),
        ),
        'an unregistered country is refused on assembly too': (
          institutionCode: 'DEUT',
          countryCode: 'ZZ',
          failure: const BicUnknownCountry('ZZ'),
        ),
      },
      outline: (example) {
        check(
          Bic.fromComponents(
            institutionCode: example.institutionCode,
            countryCode: example.countryCode,
            locationCode: 'FF',
          ).reasonOrNull,
        ).equals(example.failure);
      },
    );

    scenario('a caller who asserts the parts gets the throw back through getOrThrow', () {
      check(
            () => Bic.fromComponents(
              institutionCode: 'DEUT',
              countryCode: 'ZZ',
              locationCode: 'FF',
            ).getOrThrow(),
          )
          .throws<MintedFormatError>()
          .has((error) => error.failure, 'failure')
          .equals(const BicUnknownCountry('ZZ'));
    });
  });
}
