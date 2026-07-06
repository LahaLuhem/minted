import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import 'support/bdd.dart';

void main() {
  feature('MintedFormatException', () {
    scenario('of renders the type name and reason in the message', () {
      check(MintedFormatException.of('Email', 'x', 'boom').message).equals('Invalid Email: boom');
      check(MintedFormatException.of('Iban', 'x', 'boom').message).equals('Invalid Iban: boom');
    });

    scenario('of carries the offending input as its source', () {
      check(
        MintedFormatException.of('Email', 'bad-input', 'boom').source as String?,
      ).equals('bad-input');
    });

    scenario('it extends FormatException, so on FormatException catches parse failures', () {
      check(() => Email.parse('nope')).throws<FormatException>();
    });
  });
}
