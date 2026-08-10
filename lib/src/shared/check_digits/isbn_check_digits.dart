import 'package:collection/collection.dart';

import 'digit_values.dart';

const _gs1Modulus = 10;
const _gs1PlainWeight = 1; // weights alternate, and a 12-digit body starts on the plain one
const _gs1TripledWeight = 3;
const _isbn10Modulus = 11;
const _isbn10LeadingWeight = 10; // each later position counts for one less
const _isbn10TenValue = 10;
const _isbn10TenGlyph = 'X'; // ten has to fit in one character, so ISO 2108 spells it X

/// The GS1 mod-10 check digit for [body], the twelve leading digits of an ISBN-13 (ISO 2108),
/// assumed already separator-free.
///
/// Over a twelve-digit body, alternating from the left is GS1's right-to-left rule; generalising
/// this to the other GTIN lengths would mean indexing from the right instead. What mod-10 cannot
/// catch: two adjacent digits differing by 5 transpose without changing the weighted sum.
String isbn13CheckDigit(String body) {
  final weightedSum = body.codeUnits
      .mapIndexed(
        (position, codeUnit) =>
            decimalValue(codeUnit) * (position.isEven ? _gs1PlainWeight : _gs1TripledWeight),
      )
      .sum;

  return ((_gs1Modulus - weightedSum % _gs1Modulus) % _gs1Modulus).toString();
}

/// The ISO 2108 mod-11 check character for [body], the nine leading digits of an ISBN-10, assumed
/// already separator-free. `0`-`9`, or `X` where the value is ten.
///
/// Mod-11 catches every adjacent transposition, which is what the ten-digit form buys over the
/// thirteen-digit one.
String isbn10CheckDigit(String body) {
  final weightedSum = body.codeUnits
      .mapIndexed(
        (position, codeUnit) => decimalValue(codeUnit) * (_isbn10LeadingWeight - position),
      )
      .sum;
  final checkValue = (_isbn10Modulus - weightedSum % _isbn10Modulus) % _isbn10Modulus;

  return checkValue == _isbn10TenValue ? _isbn10TenGlyph : checkValue.toString();
}
