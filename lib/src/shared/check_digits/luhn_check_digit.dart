import 'package:collection/collection.dart';

import '../digit_values.dart';

const _modulus = 10;
const _doubledWeight = 2;
const _doubledCeiling = 9; // doubling past 9 is folded back by subtracting 9

/// The ISO/IEC 7812-1 Annex B (Luhn) mod-10 check digit for [bodyDigits], everything before a card
/// number's final digit, assumed already separator-free.
///
/// Doubling alternates from the right, starting on [bodyDigits]'s last digit, so the check digit
/// itself is never doubled. Mod-10 misses a `09`/`90` transposition and the twin errors 22/55,
/// 33/66 and 44/77.
String luhnCheckDigit(String bodyDigits) {
  final weightedSum = bodyDigits.codeUnits.reversed
      .mapIndexed(
        (position, codeUnit) =>
            position.isEven ? _doubled(decimalValue(codeUnit)) : decimalValue(codeUnit),
      )
      .sum;

  return ((_modulus - weightedSum % _modulus) % _modulus).toString();
}

int _doubled(int digitValue) {
  final doubledValue = digitValue * _doubledWeight;

  return doubledValue > _doubledCeiling ? doubledValue - _doubledCeiling : doubledValue;
}
