/// Digit fixtures written as text, since `Digits` takes values rather than a string.
///
/// Keeps example tables reading as the identifiers they describe (`prefix: '978'`) instead of as
/// int lists, and does the decode a consumer would do in one place.
library;

import 'package:minted/minted.dart';

/// The [Digits] of [text], which must be decimal digits only.
Digits digitsOf(String text) =>
    Digits.tryFrom([for (final codeUnit in text.codeUnits) codeUnit - _asciiZero])!;

const _asciiZero = 0x30;
