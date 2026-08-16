// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted/minted.dart';

void main() {
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
