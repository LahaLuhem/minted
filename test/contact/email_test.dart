import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Email', () {
    // Acceptance and normalisation in one table: the canonical form doubles as
    // the expected outcome. A String means "accepted and normalised to this". `null` means "rejected".
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
      check(Email.tryParse('a@B.com')!).equals(Email.tryParse('a@b.com')!);
    });

    scenario('addresses are not equal when their local-parts differ by case', () {
      check(Email.tryParse('A@b.com')! == Email.tryParse('a@b.com')!).isFalse();
    });

    scenario('an email exposes its local-part and domain', () {
      final parsedEmail = Email.tryParse('jane.doe@example.com')!;

      check(parsedEmail.localPart).equals('jane.doe');
      check(parsedEmail.domain).equals('example.com');
    });

    scenario('an email builds a mailto: URI', () {
      check(Email.tryParse('jane.doe@example.com')!.mailtoUri.toString())
          .equals('mailto:jane.doe@example.com');
    });

    scenario('every door reports the one failure the engine can distinguish', () {
      // email_validator exposes a single bool, so a finer diagnosis would be a guess.
      check(Email.parse('nope').reasonOrNull).equals(EmailFailure.malformed);
      check(() => Email.fromComponents(localPart: 'a b', domain: 'example.com'))
          .throws<MintedFormatException>()
          .has((error) => error.failure, 'failure')
          .equals(EmailFailure.malformed);
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Email.parse('nope')).equals(const ParseFailure(EmailFailure.malformed));
      check(Email.parse('jane@example.com').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Email.tryParse('nope')).isNull();
      check(Email.tryParse('jane@Example.COM')?.value).equals('jane@example.com');
    });

    scenario('fromComponents assembles and normalises the address', () {
      check(Email.fromComponents(localPart: 'Jane.Doe', domain: 'Example.COM').value)
          .equals('Jane.Doe@example.com');
    });

    scenario('fromDomainLabels joins the labels with dots', () {
      check(
        Email.fromDomainLabels(localPart: 'jane', domainLabels: ['mail', 'example', 'com']).value,
      ).equals('jane@mail.example.com');
    });

    scenario('fromComponents throws MintedFormatException on invalid parts', () {
      check(() => Email.fromComponents(localPart: 'a b', domain: 'example.com'))
          .throws<MintedFormatException>();
    });

    scenario('fromDomainLabels throws MintedFormatException on empty labels', () {
      check(() => Email.fromDomainLabels(localPart: 'jane', domainLabels: []))
          .throws<MintedFormatException>();
    });

    scenario('an assembly failure carries the offending parts as its source', () {
      check(() => Email.fromComponents(localPart: 'a b', domain: 'example.com'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('a b@example.com');
    });
  });
}
