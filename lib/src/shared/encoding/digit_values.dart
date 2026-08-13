/// @docImport '../../numerics/digits.dart';
library;

const _asciiZero = 0x30;
const _asciiNine = 0x39;

/// The value of a single decimal character, `0`-`9`. Anything else yields -1, so a number assembled
/// from junk fails validation downstream rather than throwing here.
///
/// Sits in `shared/` rather than `shared/check_digits/` because it is not check-digit-specific:
/// every algorithm there decodes with it, and so does [Digits].
int decimalValue(int codeUnit) =>
    codeUnit >= _asciiZero && codeUnit <= _asciiNine ? codeUnit - _asciiZero : -1;

/// The ASCII code unit spelling [digitValue], the inverse of [decimalValue].
///
/// Assumes `0`-`9`, which is what a validated digit sequence holds; no check-digit algorithm needs
/// this direction, only rendering does.
int decimalCodeUnit(int digitValue) => digitValue + _asciiZero;

/// The values of [input]'s characters, ready for [Digits.tryFrom].
///
/// For a validated whole handing back a digits-only part. A non-digit yields -1 as [decimalValue]
/// does, which makes [Digits.tryFrom] return null rather than minting something that lies.
List<int> decimalValues(String input) => [
  for (final codeUnit in input.codeUnits) decimalValue(codeUnit),
];
