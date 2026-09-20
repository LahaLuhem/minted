import 'package:characters/characters.dart';
import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../../../test/support/bdd.dart';

// Passing a constrained value to these is the assertion: each call is a type error unless the type implements
// what it constrains.
int asInt(int value) => value;

double asDouble(double value) => value;

String asString(String value) => value;

Uint asUint(Uint value) => value;

void main() {
  feature('the transparent representation', () {
    scenario('a constrained number reads as the number it constrains', () {
      const digit = DigitConstants.d7;
      final port = Uint16.tryFrom(8080)!;

      check(asInt(digit)).equals(7);
      check(asInt(port)).equals(8080);
      check(asDouble(Probability.tryFrom(0.25)!)).equals(0.25);
      check(digit + 1).equals(8);
      check(digit.toRadixString(2)).equals('111');
      check(<int>[digit, port].reduce((left, right) => left + right)).equals(8087);
    });

    // NaturalNumber narrows Uint, which narrows int, so it reaches both without a hop through value.
    scenario('a natural number reads as the Uint it narrows, and as the int under that', () {
      const natural = NaturalNumberConstants.one;

      check(asUint(natural).value).equals(1);
      check(asInt(natural)).equals(1);
      check(natural + 1).equals(2);
    });

    // AsciiLetter declares no String of its own: it narrows down to AsciiChar, where it comes from.
    scenario('an Ascii text type reads as the String it constrains, transitively', () {
      final letter = AsciiLetter.tryFrom('Q')!;
      final letters = AsciiLetters.tryFrom('abc')!;

      check(asString(letter)).equals('Q');
      check(asString(AsciiAlphanumeric.tryFrom('7')!)).equals('7');
      check(letters.length).equals(3);
      check(letters.toUpperCase()).equals('ABC');
      check(letter + letters).equals('Qabc');
    });

    // Why Percentage is the one number left opaque: its unit lives in a method, not an operator.
    scenario('a percentage keeps its unit behind of rather than arithmetic', () {
      final fifteen = Percentage.tryFrom(15)!;

      check(fifteen.value).equals(15);
      check(fifteen.of(200)).equals(30);
    });

    // Why Char, Letter and Letters stay opaque: one grapheme, 2 code units.
    scenario('a Char is one character that String would measure as two', () {
      final emoji = Char.tryFrom('\u{1F389}')!;

      check(emoji.value.characters.length).equals(1);
      check(emoji.value.length).equals(2);
    });
  });
}
