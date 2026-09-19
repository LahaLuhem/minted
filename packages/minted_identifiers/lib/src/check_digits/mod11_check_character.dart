import 'package:collection/collection.dart';
import 'package:minted/internal.dart';

const _modulus = 11;
const _weightAboveLength = 1; // the leading digit counts for one more than the body is long
const _tenValue = 10;
const _tenGlyph = 'X'; // ten has to fit in one character, so both standards spell it X

/// The weighted mod-11 check character for [bodyDigits], `0`-`9` or `X` for 10. Assumed separator-free.
///
/// Weights count down from one above the body's length, which is what lets one version cover both ISO
/// 2108's ISBN-10 and ISO 3297's ISSN. Unlike mod-10, mod-11 catches every transposition.
String mod11CheckCharacter(String bodyDigits) {
  final leadingWeight = bodyDigits.length + _weightAboveLength;
  final weightedSum = bodyDigits.codeUnits
      .mapIndexed((position, codeUnit) => decimalValue(codeUnit) * (leadingWeight - position))
      .sum;
  final checkValue = (_modulus - weightedSum % _modulus) % _modulus;

  return checkValue == _tenValue ? _tenGlyph : checkValue.toString();
}
