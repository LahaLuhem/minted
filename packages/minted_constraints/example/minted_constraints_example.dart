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

  // One character to a reader is one grapheme cluster: the skin tone, flag and family below are two,
  // two and five code points, each filling one slot.
  // #region char
  print(Char.tryFrom('\u{1F44D}\u{1F3FD}')?.value); // a skin-toned thumbs-up, one character
  print(Char.tryFrom('\u{1F1F3}\u{1F1F1}') != null); // true (a flag, two regional indicators)
  print(Char.tryFrom('ab')); // null (two characters)
  print(Char.tryFrom('\uD83D')); // null (half a surrogate pair is no character)
  print(
    Letter.tryFrom('\u{00D8}')?.value,
  ); // O with stroke: a Danish initial, refused by AsciiLetter
  print(Letter.tryFrom('e\u{0301}')?.value); // a decomposed accent is one letter
  print(Letter.tryFrom('\u{1F44D}')); // null (one character, but no letter)
  // #endregion
}
