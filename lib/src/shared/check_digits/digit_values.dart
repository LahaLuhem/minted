const _asciiZero = 0x30;
const _asciiNine = 0x39;

/// The value of a single decimal character, `0`-`9`. Anything else yields -1, so a number assembled
/// from junk fails validation downstream rather than throwing here.
///
/// The one piece every check-digit algorithm shares; each standard's own character map builds on it.
int decimalValue(int codeUnit) =>
    codeUnit >= _asciiZero && codeUnit <= _asciiNine ? codeUnit - _asciiZero : -1;
