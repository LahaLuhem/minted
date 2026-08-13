import 'package:collection/collection.dart';

import '../encoding/digit_values.dart';

const _modulus = 11;
const _weightAboveLength = 1; // the leading digit counts for one more than the body is long
const _tenValue = 10;
const _tenGlyph = 'X'; // ten has to fit in one character, so both standards spell it X

/// The weighted mod-11 check character for [bodyDigits], everything before the check character itself,
/// assumed already separator-free. `0`-`9`, or `X` where the value is ten.
///
/// Weights descend from one above [bodyDigits]'s length down to 2, which is what lets one implementation
/// serve ISO 2108's ISBN-10 (nine digits, leading weight 10) and ISO 3297's ISSN (seven, leading weight 8).
/// Unlike the mod-10 family, mod-11 catches every transposition.
String mod11CheckCharacter(String bodyDigits) {
  final leadingWeight = bodyDigits.length + _weightAboveLength;
  final weightedSum = bodyDigits.codeUnits
      .mapIndexed((position, codeUnit) => decimalValue(codeUnit) * (leadingWeight - position))
      .sum;
  final checkValue = (_modulus - weightedSum % _modulus) % _modulus;

  return checkValue == _tenValue ? _tenGlyph : checkValue.toString();
}
