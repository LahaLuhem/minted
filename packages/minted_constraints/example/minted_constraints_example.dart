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

  // The plurals hold text, so they are extension types over String, with the elements on a getter.
  // #region plurals
  final initials = Letters.tryFrom('J\u{00D8}')!;
  print(initials.value); // JO with stroke
  print(initials.letters.map((letter) => letter.value).toList()); // [J, O with stroke]
  print(AsciiAlphanumerics.tryFrom('NWBK60161331926819')?.value); // a BBAN
  print(AsciiAlphanumerics.tryFrom('NWBK 6016')); // null (a grouped BBAN is not the charset)
  print(AsciiLetters.tryFrom('GB')?.value); // GB
  // #endregion

  // `Uint` and `NaturalNumber` are constraint types: a range over a number with no standard text
  // form, so they take `tryFrom(int)` and no `parse`. Zero is the one value they disagree on.
  // #region quantities
  print(Uint.tryFrom(0)?.value); // 0 (an empty cart is a real count)
  print(NaturalNumber.tryFrom(0)); // null (a page size of zero is not)
  print(Uint.tryFrom(-1)); // null, rather than wrapping to a huge number the way C would
  // #endregion

  // The fixed widths bound both ends, and each width is its own type, so a Uint8 cannot be passed
  // where a Uint4 is wanted.
  // #region fixedwidths
  print(Uint8.tryFrom(255)?.value); // 255
  print(Uint8.tryFrom(256)); // null (refused, not truncated to 0)
  // #endregion

  // `Percentage` is the other kind of constraint type: it bounds nothing, and names the unit,
  // since 15 and 0.15 are both plausible readings of "fifteen percent".
  // #region percentage
  final discount = Percentage.tryFrom(15)!; // the percent, which is what `.value` holds
  print(discount.fraction); // 0.15 (the same proportion, said the other way)
  print(discount.of(200)); // 30.0
  print(Percentage.tryFromFraction(0.29)!.value); // 29.0, where 0.29 * 100 is 28.999999999999996
  print(Percentage.tryFrom(-12)?.value); // -12.0 (churn is real; nothing is bounded)
  print(Percentage.tryFrom(double.nan)); // null (finiteness is the only invariant)
  // #endregion

  // `Probability` is the bounded one. The range states the convention, so one door is enough.
  // #region probability
  final chance = Probability.tryFrom(0.15)!;
  print(chance.complement.value); // 0.85 (the event not happening)
  print(chance.toPercentage().value); // 15.0, and this direction never fails
  print(Probability.tryFrom(1)!.isCertain); // true (both ends are members, reported not refused)
  print(Probability.tryFrom(1.5)); // null, unlike a Percentage, which is unbounded
  print(Probability.tryFromPercentage(Percentage.tryFrom(250)!)); // null (the other direction can)
  // #endregion
}
