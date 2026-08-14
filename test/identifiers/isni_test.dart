import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';
import '../support/digits.dart';

void main() {
  feature('Isni', () {
    // The compact sixteen-character form doubles as the expected outcome: a String means "accepted
    // and normalised to this", null means "rejected". Valid rows are real, published identifiers.
    scenarioOutline<({String input, String? canonical})>(
      'Isni.tryParse normalises accepted input and rejects input that fails a check',
      examples: {
        'a compact ISNI': (input: '0000000121032683', canonical: '0000000121032683'),
        'the spaced grouping ISNI prints': (
          input: '0000 0001 2103 2683',
          canonical: '0000000121032683',
        ),
        'an ORCID iD, hyphenated the way ORCID prints it': (
          input: '0000-0002-1825-0097',
          canonical: '0000000218250097',
        ),
        'an ORCID iD whose check character is X': (
          input: '0000-0002-1694-233X',
          canonical: '000000021694233X',
        ),
        'a lower-case x is upper-cased before the check': (
          input: '0000-0002-1694-233x',
          canonical: '000000021694233X',
        ),
        'a corrupted check character': (input: '0000000121032684', canonical: null),
        'two transposed digits inside the number': (input: '0000000112032683', canonical: null),
        'fifteen characters is one short': (input: '000000012103268', canonical: null),
        'seventeen is one long': (input: '00000001210326833', canonical: null),
        'X anywhere but last is not an ISNI character': (
          input: '00000001210326X3',
          canonical: null,
        ),
        'letters are not an ISNI': (input: 'ABCDEFGHIJKLMNOP', canonical: null),
        'empty': (input: '', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as an ISNI ...
        final parsedIsni = Isni.tryParse(example.input);

        // Then it is normalised to the compact form, or rejected (null).
        check(parsedIsni?.value).equals(example.canonical);
      },
    );

    scenario('the spaced, hyphenated and compact spellings of one identity are equal', () {
      final compact = Isni.tryParse('0000000218250097')!;

      check(Isni.tryParse('0000 0002 1825 0097')!).equals(compact);
      check(Isni.tryParse('0000-0002-1825-0097')!).equals(compact);
    });

    scenarioOutline<({String input, String formatted, String checkCharacter})>(
      'an ISNI rebuilds its printed grouping and exposes its check character',
      examples: {
        'a numeric check character': (
          input: '0000000121032683',
          formatted: '0000 0001 2103 2683',
          checkCharacter: '3',
        ),
        'a check character of ten': (
          input: '000000021694233X',
          formatted: '0000 0002 1694 233X',
          checkCharacter: 'X',
        ),
      },
      outline: (example) {
        final parsedIsni = Isni.tryParse(example.input)!;

        check(parsedIsni.formatted).equals(example.formatted);
        check(parsedIsni.checkCharacter).equals(example.checkCharacter);
      },
    );

    // An ORCID iD is an ISNI from ORCID's block. Reported, never gated: gating would refuse most
    // of the standard this type exists to hold.
    scenarioOutline<({String input, bool isInOrcidBlock})>(
      'an ISNI says whether it is also an ORCID iD',
      examples: {
        "Isaac Newton's ISNI sits below the block": (
          input: '0000000121032683',
          isInOrcidBlock: false,
        ),
        'an ORCID iD sits inside it': (input: '0000-0002-1825-0097', isInOrcidBlock: true),
        'so does one ending in X': (input: '0000-0002-1694-233X', isInOrcidBlock: true),
      },
      outline: (example) {
        check(Isni.tryParse(example.input)!.isInOrcidBlock).equals(example.isInOrcidBlock);
      },
    );

    // Built rather than transcribed, so each carries a real check character. Sixteen digits
    // overflow the web's safe integer range, which is why the block test compares text.
    scenario('the block boundary is inclusive at its lower bound', () {
      final atStart = Isni.fromBody(Digits.tryFrom([0, 0, 0, 0, 0, 0, 0, 1, 5, 0, 0, 0, 0, 0, 0])!);
      final justBelow = Isni.fromBody(
        Digits.tryFrom([0, 0, 0, 0, 0, 0, 0, 1, 4, 9, 9, 9, 9, 9, 9])!,
      );

      check(atStart.isInOrcidBlock).isTrue();
      check(justBelow.isInOrcidBlock).isFalse();
    });

    scenarioOutline<({String input, IsniFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'empty input has nothing to weigh': (input: '', failure: const IsniWrongLength(0)),
        'fifteen characters is one short': (
          input: '000000012103268',
          failure: const IsniWrongLength(15),
        ),
        'a stray letter is not an ISNI character': (
          input: '000000012103268A',
          failure: const IsniInvalidCharacters(),
        ),
        'X is only the check character, never an inner one': (
          input: '00000001210326X3',
          failure: const IsniInvalidCharacters(),
        ),
        'a corrupted check character fails MOD 11-2': (
          input: '0000000121032684',
          failure: const IsniChecksumFailed(),
        ),
        'a transposition fails it too': (
          input: '0000000112032683',
          failure: const IsniChecksumFailed(),
        ),
      },
      outline: (example) => check(Isni.parse(example.input).reasonOrNull).equals(example.failure),
    );

    // Pinned because the two mod-11s share a modulus and an X glyph, which makes them look
    // interchangeable when they are not: mod11CheckCharacter rejects every one of these.
    scenario('the weighted mod-11 would reject these, so the two algorithms cannot be swapped', () {
      check(Isni.tryParse('0000000218250097')?.value).equals('0000000218250097');
      check(Isni.tryParse('0000000121032683')?.value).equals('0000000121032683');
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Isni.parse('0000000121032684')).equals(const ParseFailure(IsniChecksumFailed()));
      check(Isni.parse('0000000121032683').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Isni.tryParse('0000000121032684')).isNull();
      check(Isni.tryParse('0000 0001 2103 2683')?.value).equals('0000000121032683');
    });

    // fromBody runs our MOD 11-2 generator; check it reproduces the published check character
    // rather than round-tripping our own output.
    scenarioOutline<({String body, String isni})>(
      'fromBody computes the check character to match the published identifier',
      examples: {
        "Isaac Newton's ISNI": (body: '000000012103268', isni: '0000000121032683'),
        'an ORCID iD': (body: '000000021825009', isni: '0000000218250097'),
        'one whose check character is X': (body: '000000021694233', isni: '000000021694233X'),
      },
      outline: (example) => check(Isni.fromBody(digitsOf(example.body)).value).equals(example.isni),
    );

    scenarioOutline<({String body, IsniFailure failure})>(
      'fromBody reports the same vocabulary as parse',
      examples: {
        'a short body cannot reach sixteen characters': (
          body: '00000001210326',
          failure: const IsniWrongLength(15),
        ),
        'a long body overshoots': (body: '0000000121032683', failure: const IsniWrongLength(17)),
      },
      outline: (example) {
        check(() => Isni.fromBody(digitsOf(example.body)))
            .throws<MintedFormatException>()
            .has((error) => error.failure, 'failure')
            .equals(example.failure);
      },
    );

    scenario('fromBody error carries the body as its source', () {
      check(() => Isni.fromBody(Digits.tryFrom([0, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 3, 2, 6])!))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('00000001210326');
    });
  });
}
