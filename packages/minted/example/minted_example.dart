// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted/minted.dart';

import 'data/enums/even_length_failure.dart';

/// Stands in for a value type's `parse`: every fallible door in the family returns one of these.
ParseOutcome<EvenLengthFailure, int> halfLengthOf(String input) =>
    input.length.isOdd ? const ParseFailure(.odd) : ParseSuccess(input.length ~/ 2);

void main() {
  // Core holds the vocabulary a parse hands back, not the value types: those live in the siblings.
  // No door throws, so the failure is in the return type and the caller picks how to read it.
  // #region outcomes
  print(halfLengthOf('abcd').getOrNull()); // 2
  print(halfLengthOf('abc').getOrNull()); // null
  print(halfLengthOf('abc').reasonOrNull?.message); // the character count is odd
  print(halfLengthOf('abc').getOrElse(() => 0)); // 0
  print(halfLengthOf('abcd').isSuccess); // true
  // #endregion

  // getOrThrow is the caller asserting the input: it hands the value back, or raises
  // MintedFormatError, an Error because a false assertion is a bug rather than input to handle.
  // #region assert
  print(halfLengthOf('abcd').getOrThrow()); // 2
  // #endregion
}
