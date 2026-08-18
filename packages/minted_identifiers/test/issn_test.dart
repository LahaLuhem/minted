import 'package:checks/checks.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';
import 'package:minted_identifiers/minted_identifiers.dart';

import 'support/bdd.dart';
import 'support/digits.dart';

void main() {
  feature('Issn', () {
    // The hyphenated form doubles as the expected outcome: a String means "accepted and normalised
    // to this", null means "rejected". Valid rows are real, published ISSNs.
    scenarioOutline<({String input, String? canonical})>(
      'Issn.tryParse normalises accepted input and rejects input that fails a check',
      examples: {
        'the ISO 3297 worked example, already hyphenated': (
          input: '0317-8471',
          canonical: '0317-8471',
        ),
        'an unhyphenated ISSN gains its hyphen': (input: '03178471', canonical: '0317-8471'),
        'Nature': (input: '0028-0836', canonical: '0028-0836'),
        'Science': (input: '0036-8075', canonical: '0036-8075'),
        'a check character of ten is X': (input: '1050-124X', canonical: '1050-124X'),
        'a lower-case x is upper-cased before the check': (
          input: '1050-124x',
          canonical: '1050-124X',
        ),
        'spaces group an ISSN as readily as the hyphen': (
          input: '0378 5955',
          canonical: '0378-5955',
        ),
        'a hyphen in the wrong place still normalises to the right one': (
          input: '037-85955',
          canonical: '0378-5955',
        ),
        'a corrupted check character': (input: '0317-8470', canonical: null),
        'two transposed digits inside the number': (input: '0137-8471', canonical: null),
        'X anywhere but last is not an ISSN character': (input: '031X-8471', canonical: null),
        'seven characters is one short': (input: '0317847', canonical: null),
        'nine characters is one long': (input: '031784715', canonical: null),
        'the 977 GTIN barcode form is not the ISSN itself': (
          input: '9770317847004',
          canonical: null,
        ),
        'letters are not an ISSN': (input: 'ABCDEFGH', canonical: null),
        'empty': (input: '', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as an ISSN ...
        final parsedIssn = Issn.tryParse(example.input);

        // Then it is normalised to the hyphenated form, or rejected (null).
        check(parsedIssn?.value).equals(example.canonical);
      },
    );

    scenario('the hyphenated and compact spellings of one title are equal', () {
      check(Issn.tryParse('03178471')!).equals(Issn.tryParse('0317-8471')!);
    });

    scenarioOutline<({String input, String compact, String checkCharacter})>(
      'an ISSN exposes its compact form and its check character',
      examples: {
        'a numeric check character': (input: '0317-8471', compact: '03178471', checkCharacter: '1'),
        'a check character of ten': (input: '1050-124X', compact: '1050124X', checkCharacter: 'X'),
        'a check character of zero': (input: '2049-3630', compact: '20493630', checkCharacter: '0'),
      },
      outline: (example) {
        final parsedIssn = Issn.tryParse(example.input)!;

        check(parsedIssn.compact).equals(example.compact);
        check(parsedIssn.checkCharacter).equals(example.checkCharacter);
      },
    );

    scenarioOutline<({String input, IssnFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'empty input has nothing to weigh': (input: '', failure: const IssnWrongLength(0)),
        'seven characters is one short': (input: '0317847', failure: const IssnWrongLength(7)),
        'the 977 GTIN barcode form is thirteen digits': (
          input: '9770317847004',
          failure: const IssnWrongLength(13),
        ),
        'a stray letter is not an ISSN character': (
          input: '0317847A',
          failure: const IssnInvalidCharacters(),
        ),
        'X is only the check character, never an inner one': (
          input: '031X8471',
          failure: const IssnInvalidCharacters(),
        ),
        'a corrupted check character fails mod-11': (
          input: '0317-8470',
          failure: const IssnChecksumFailed(),
        ),
        'a transposition fails it too': (input: '0137-8471', failure: const IssnChecksumFailed()),
      },
      outline: (example) => check(Issn.parse(example.input).reasonOrNull).equals(example.failure),
    );

    // Mod-11 is the one algorithm here with no transposition blind spot, where the mod-10 family
    // cannot see a swapped adjacent pair differing by five. Each row swaps exactly such a pair in a
    // real ISSN, so a "simplification" to mod-10 would turn these green and be caught.
    scenarioOutline<({String valid, String transposed})>(
      'mod-11 catches the adjacent transpositions mod-10 would miss',
      examples: {
        "Nature's adjacent 8 and 3": (valid: '0028-0836', transposed: '0028-0386'),
        'a leading 0 and 5': (valid: '1050-124X', transposed: '1500-124X'),
        'the same pair the other way': (valid: '1050-124X', transposed: '1005-124X'),
      },
      outline: (example) {
        check(Issn.tryParse(example.valid)?.value).equals(example.valid);
        check(Issn.tryParse(example.transposed)).isNull();
      },
    );

    scenario('parse reports the failure rather than throwing', () {
      check(Issn.parse('0317-8470')).equals(const ParseFailure(IssnChecksumFailed()));
      check(Issn.parse('0317-8471').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Issn.tryParse('0317-8470')).isNull();
      check(Issn.tryParse('03178471')?.value).equals('0317-8471');
    });

    // fromBody runs our mod-11 generator; check it reproduces the published check character rather
    // than round-tripping our own output.
    scenarioOutline<({String body, String issn})>(
      'fromBody computes the check character to match the published ISSN',
      examples: {
        'the ISO 3297 worked example': (body: '0317847', issn: '0317-8471'),
        'Nature': (body: '0028083', issn: '0028-0836'),
        'Science': (body: '0036807', issn: '0036-8075'),
        'Nature online': (body: '1476468', issn: '1476-4687'),
        'a check character of ten spells X': (body: '1050124', issn: '1050-124X'),
      },
      outline: (example) =>
          check(Issn.fromBody(digitsOf(example.body)).getOrThrow().value).equals(example.issn),
    );

    scenarioOutline<({String body, IssnFailure failure})>(
      'fromBody reports the same vocabulary as parse',
      examples: {
        'a short body cannot reach eight characters': (
          body: '03178',
          failure: const IssnWrongLength(6),
        ),
      },
      outline: (example) {
        check(Issn.fromBody(digitsOf(example.body)).reasonOrNull).equals(example.failure);
      },
    );

    scenario('a caller who asserts the body gets the throw back through getOrThrow', () {
      check(() => Issn.fromBody(Digits.tryFrom([0, 3, 1, 7, 8])!).getOrThrow())
          .throws<MintedFormatError>()
          .has((error) => error.failure, 'failure')
          .equals(const IssnWrongLength(6));
    });
  });
}
