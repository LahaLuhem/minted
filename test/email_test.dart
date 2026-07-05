import 'package:checks/checks.dart';
import 'package:minted/minted.dart';
import 'package:test/test.dart';

void main() {
  group('Email.tryParse', () {
    test('accepts a well-formed address', () {
      check(Email.tryParse('jane.doe@example.com')).isNotNull();
    });

    test('accepts plus-addressing and subdomains', () {
      check(Email.tryParse('user+tag@mail.example.co.uk')).isNotNull();
    });

    test('trims surrounding whitespace', () {
      check(Email.parse('  jane@example.com  ').value).equals('jane@example.com');
    });

    for (final invalid in const ['not-an-email', 'a@', '@b.com', 'a b@c.com', '']) {
      test('rejects "$invalid"', () {
        check(Email.tryParse(invalid)).isNull();
      });
    }
  });

  group('Email normalisation', () {
    test('lower-cases the domain', () {
      check(Email.parse('jane@Example.COM').domain).equals('example.com');
    });

    test('preserves local-part case', () {
      check(Email.parse('Jane.Doe@example.com').localPart).equals('Jane.Doe');
    });

    test('equal when domains differ only by case', () {
      check(Email.parse('a@B.com')).equals(Email.parse('a@b.com'));
    });

    test('not equal when local-parts differ by case', () {
      check(Email.parse('A@b.com') == Email.parse('a@b.com')).isFalse();
    });
  });

  group('Email helpers', () {
    final email = Email.parse('jane.doe@example.com');

    test('splits into local-part and domain', () {
      check(email.localPart).equals('jane.doe');
      check(email.domain).equals('example.com');
    });

    test('builds a mailto: URI', () {
      check(email.mailtoUri.toString()).equals('mailto:jane.doe@example.com');
    });
  });

  group('Email.parse', () {
    test('throws MintedFormatException on invalid input', () {
      check(() => Email.parse('nope')).throws<MintedFormatException>();
    });
  });
}
