import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Isbn', () {
    // The canonical thirteen-digit form doubles as the expected outcome: a String means "accepted
    // and normalised to this", null means "rejected". Valid rows are published worked examples.
    scenarioOutline<({String input, String? canonical})>(
      'Isbn.tryParse normalises accepted input and rejects input that fails a check',
      examples: {
        'a hyphenated ISBN-13': (input: '978-0-306-40615-7', canonical: '9780306406157'),
        'its ISBN-10 twin folds to the same number': (
          input: '0-306-40615-2',
          canonical: '9780306406157',
        ),
        'spaces group an ISBN just as often as hyphens': (
          input: '978 3 16 148410 0',
          canonical: '9783161484100',
        ),
        'an X check digit stands for ten in the ISBN-10 form': (
          input: '0-8044-2957-X',
          canonical: '9780804429573',
        ),
        'a lower-case x is upper-cased before the check': (
          input: '080442957x',
          canonical: '9780804429573',
        ),
        'a 979-10 French ISBN, a range with no ten-digit equivalent': (
          input: '979-10-90636-07-1',
          canonical: '9791090636071',
        ),
        'a 979-8 ISBN, the range self-publishing draws from': (
          input: '979-8-6204-9040-0',
          canonical: '9798620490400',
        ),
        'a corrupted final check digit': (input: '9780306406158', canonical: null),
        'two transposed digits inside the number': (input: '9780306046157', canonical: null),
        'an ISBN-10 body with the wrong check character': (input: '030640615X', canonical: null),
        'twelve digits is neither generation': (input: '978030640615', canonical: null),
        'the ISMN range is printed music, not a book': (input: '9790260000438', canonical: null),
        'the ISSN prefix is a periodical': (input: '9771234567003', canonical: null),
        'letters are not an ISBN of any length': (input: 'ABCDEFGHIJ', canonical: null),
        'empty': (input: '', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as an ISBN ...
        final parsedIsbn = Isbn.tryParse(example.input);

        // Then it is normalised to the thirteen-digit form, or rejected (null).
        check(parsedIsbn?.value).equals(example.canonical);
      },
    );

    scenario('the two generations of one book are equal', () {
      check(Isbn.tryParse('0-306-40615-2')!).equals(Isbn.tryParse('978-0-306-40615-7')!);
    });

    scenario('an ISBN exposes its prefix, body, and check digit', () {
      final parsedIsbn = Isbn.tryParse('978-0-306-40615-7')!;

      check(parsedIsbn.prefix).equals('978');
      check(parsedIsbn.body).equals('030640615');
      check(parsedIsbn.checkDigit).equals(Digit.from(7));
    });

    // The legacy form is rebuilt, not stored, so these check our mod-11 generator against the
    // published ISBN-10 rather than round-tripping our own output.
    scenarioOutline<({String input, String? isbn10})>(
      'a 978 ISBN rebuilds its legacy ten-digit form, and a 979 one has none',
      examples: {
        'a numeric check digit': (input: '9780306406157', isbn10: '0306406152'),
        'a check digit of ten spells X': (input: '9783161484100', isbn10: '316148410X'),
        'a 979-10 ISBN never had a ten-digit form': (input: '9791090636071', isbn10: null),
        'nor did a 979-8 one': (input: '9798620490400', isbn10: null),
      },
      outline: (example) => check(Isbn.tryParse(example.input)!.isbn10).equals(example.isbn10),
    );

    scenarioOutline<({String input, IsbnFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'empty input has no digits to weigh': (input: '', failure: const IsbnWrongLength(0)),
        'twelve digits is neither generation': (
          input: '978030640615',
          failure: const IsbnWrongLength(12),
        ),
        'a stray letter is not an ISBN character': (
          input: '97803064061A7',
          failure: const IsbnInvalidCharacters(),
        ),
        'X is only the ISBN-10 check digit, never an inner character': (
          input: '97X0306406157',
          failure: const IsbnInvalidCharacters(),
        ),
        'a periodical carries the ISSN prefix': (
          input: '9771234567003',
          failure: const IsbnInvalidPrefix('977'),
        ),
        'printed music is named as ISMN rather than called a typo': (
          input: '9790260000438',
          failure: const IsbnInvalidPrefix('9790'),
        ),
        'a corrupted final digit fails mod-10': (
          input: '9780306406158',
          failure: const IsbnChecksumFailed(),
        ),
        'a corrupted ISBN-10 fails mod-11': (
          input: '0306406153',
          failure: const IsbnChecksumFailed(),
        ),
      },
      outline: (example) => check(Isbn.parse(example.input).reasonOrNull).equals(example.failure),
    );

    scenario('the ISMN failure says what the number actually is', () {
      check(
        Isbn.parse('9790260000438').reasonOrNull?.message,
      ).equals('"9790" is the ISMN range for printed music, not an ISBN');
    });

    // A property of GS1 mod-10, not a gap in ours: swapping adjacent digits five apart leaves the
    // weighted sum unchanged. Pinned so nobody "fixes" it later.
    scenario('mod-10 cannot catch a transposition of two adjacent digits differing by five', () {
      check(Isbn.tryParse('9780306401657')?.value).equals('9780306401657');
      check(Isbn.tryParse('9780306406157')?.value).equals('9780306406157');
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Isbn.parse('9780306406158')).equals(const ParseFailure(IsbnChecksumFailed()));
      check(Isbn.parse('9780306406157').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Isbn.tryParse('9780306406158')).isNull();
      check(Isbn.tryParse('0-306-40615-2')?.value).equals('9780306406157');
    });

    // fromComponents runs our GS1 mod-10 generator; check it reproduces the published check digit
    // across both Bookland prefixes.
    scenarioOutline<({String prefix, String body, String isbn})>(
      'fromComponents computes the check digit to match the published ISBN',
      examples: {
        '978, a numeric check digit': (prefix: '978', body: '030640615', isbn: '9780306406157'),
        '978, a check digit of zero': (prefix: '978', body: '316148410', isbn: '9783161484100'),
        '979-10, the French range': (prefix: '979', body: '109063607', isbn: '9791090636071'),
        '979-8, the self-publishing range': (
          prefix: '979',
          body: '862049040',
          isbn: '9798620490400',
        ),
      },
      outline: (example) {
        check(
          Isbn.fromComponents(
            prefix: Digits.parse(example.prefix).getOrThrow(),
            body: Digits.parse(example.body).getOrThrow(),
          ).value,
        ).equals(example.isbn);
      },
    );

    scenarioOutline<({String prefix, String body, IsbnFailure failure})>(
      'fromComponents reports the same vocabulary as parse',
      examples: {
        'a short body cannot reach thirteen digits': (
          prefix: '978',
          body: '03064061',
          failure: const IsbnWrongLength(12),
        ),
        'a prefix outside the book ranges': (
          prefix: '977',
          body: '123456700',
          failure: const IsbnInvalidPrefix('977'),
        ),
        'the ISMN range is refused on assembly too': (
          prefix: '979',
          body: '012345678',
          failure: const IsbnInvalidPrefix('9790'),
        ),
      },
      outline: (example) {
        check(
              () => Isbn.fromComponents(
                prefix: Digits.parse(example.prefix).getOrThrow(),
                body: Digits.parse(example.body).getOrThrow(),
              ),
            )
            .throws<MintedFormatException>()
            .has((error) => error.failure, 'failure')
            .equals(example.failure);
      },
    );

    scenario('fromComponents error carries the components as its source', () {
      check(
            () => Isbn.fromComponents(
              prefix: Digits.parse('978').getOrThrow(),
              body: Digits.parse('03064061').getOrThrow(),
            ),
          )
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('978 + 03064061');
    });
  });
}
