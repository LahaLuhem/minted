import 'package:collection/collection.dart';
import 'package:minted/internal.dart';

const _modulus = 10;
const _plainWeight = 1;
const _tripledWeight = 3;

/// The GS1 mod-10 check digit for [bodyDigits], everything before the last digit of a GTIN or an ISBN-13.
/// Assumed separator-free.
///
/// Weights alternate from the right, so one version covers every GS1 length. Mod-10 misses a swap of
/// 2 neighbouring digits that differ by 5.
String gs1CheckDigit(String bodyDigits) {
  final weightedSum = bodyDigits.codeUnits.reversed
      .mapIndexed(
        (position, codeUnit) =>
            decimalValue(codeUnit) * (position.isEven ? _tripledWeight : _plainWeight),
      )
      .sum;

  return ((_modulus - weightedSum % _modulus) % _modulus).toString();
}
