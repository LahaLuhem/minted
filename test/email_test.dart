import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import 'support/bdd.dart';

void main() {
  feature('Email', () {
    // Acceptance and normalisation in one table: the canonical form doubles as
    // the expected outcome. A String means "accepted and normalised to this";
    // null means "rejected".
    scenarioOutline<({String input, String? canonical})>(
      'Email.tryParse normalises accepted input and rejects malformed input',
      examples: {
        'a plain address': (input: 'jane.doe@example.com', canonical: 'jane.doe@example.com'),
        'plus-addressing and subdomains': (
          input: 'user+tag@mail.example.co.uk',
          canonical: 'user+tag@mail.example.co.uk',
        ),
        'surrounding whitespace is trimmed': (
          input: '  jane@example.com  ',
          canonical: 'jane@example.com',
        ),
        'the domain is lower-cased': (input: 'jane@Example.COM', canonical: 'jane@example.com'),
        'the local-part keeps its case': (
          input: 'Jane.Doe@example.com',
          canonical: 'Jane.Doe@example.com',
        ),
        'no domain': (input: 'a@', canonical: null),
        'no local-part': (input: '@b.com', canonical: null),
        'internal whitespace': (input: 'a b@c.com', canonical: null),
        'not an address at all': (input: 'not-an-email', canonical: null),
        'empty': (input: '', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as an email ...
        final parsedEmail = Email.tryParse(example.input);

        // Then it is normalised to the canonical form, or rejected (null).
        check(parsedEmail?.value).equals(example.canonical);
      },
    );

    scenario('addresses are equal when their domains differ only by case', () {
      check(Email.parse('a@B.com')).equals(Email.parse('a@b.com'));
    });

    scenario('addresses are not equal when their local-parts differ by case', () {
      check(Email.parse('A@b.com') == Email.parse('a@b.com')).isFalse();
    });

    scenario('an email exposes its local-part and domain', () {
      final parsedEmail = Email.parse('jane.doe@example.com');

      check(parsedEmail.localPart).equals('jane.doe');
      check(parsedEmail.domain).equals('example.com');
    });

    scenario('an email builds a mailto: URI', () {
      check(
        Email.parse('jane.doe@example.com').mailtoUri.toString(),
      ).equals('mailto:jane.doe@example.com');
    });

    scenario('Email.parse throws MintedFormatException on malformed input', () {
      check(() => Email.parse('nope')).throws<MintedFormatException>();
    });
  });
}
