const _asciiZero = 0x30;
const _asciiNine = 0x39;

/// The value of a single decimal character, `0`-`9`. Anything else gives -1, so a number built out of
/// junk fails validation downstream instead of throwing here.
int decimalValue(int codeUnit) =>
    codeUnit >= _asciiZero && codeUnit <= _asciiNine ? codeUnit - _asciiZero : -1;

/// The ASCII code unit spelling [digitValue], the inverse of [decimalValue]. Assumes `0`-`9`, which
/// is what a validated digit sequence holds.
int decimalCodeUnit(int digitValue) => digitValue + _asciiZero;

/// The values of [input]'s characters from [start] to [end] (exclusive, the whole string when omitted),
/// ready for `Digits.tryFrom`.
///
/// Read straight off the code units, so a validated whole hands back a digits-only part without allocating
/// a substring. A non-digit gives -1, so `Digits.tryFrom` returns null rather than minting something
/// that lies.
List<int> decimalValues(String input, [int start = 0, int? end]) => [
  for (var index = start; index < (end ?? input.length); index++)
    decimalValue(input.codeUnitAt(index)),
];
