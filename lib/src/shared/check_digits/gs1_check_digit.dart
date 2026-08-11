import 'package:collection/collection.dart';

import '../digit_values.dart';

const _modulus = 10;
const _plainWeight = 1;
const _tripledWeight = 3;

/// The GS1 mod-10 check digit for [bodyDigits], everything before the final digit of a GTIN or an
/// ISBN-13, assumed already separator-free.
///
/// Weights alternate from the right, tripling [bodyDigits]'s last digit, so one implementation serves
/// every GS1 length. Mod-10 misses a transposition of two adjacent digits differing by 5.
String gs1CheckDigit(String bodyDigits) {
  final weightedSum = bodyDigits.codeUnits.reversed
      .mapIndexed(
        (position, codeUnit) =>
            decimalValue(codeUnit) * (position.isEven ? _tripledWeight : _plainWeight),
      )
      .sum;

  return ((_modulus - weightedSum % _modulus) % _modulus).toString();
}
