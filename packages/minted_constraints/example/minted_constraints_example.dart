// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted_constraints/minted_constraints.dart';

void main() {
  // A "single character" slot is a String almost everywhere, so nothing stops none or twenty.
  // #region ascii
  print(AsciiChar.tryFrom('x')?.value); // x
  print(AsciiChar.tryFrom('xy')); // null (two characters is not one)
  print(AsciiChar.tryFrom('')); // null (nor is none)
  print(AsciiChar.tryFrom('\t')?.isControl); // true (a tab is a character, and says which kind)
  print(AsciiLetter.tryFrom('Q')?.value); // Q
  print(AsciiLetter.tryFrom('7')); // null (a digit is a character, but not a letter)
  // #endregion
}
