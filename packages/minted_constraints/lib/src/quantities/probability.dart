import 'package:minted/internal.dart';

import 'percentage.dart';

/// A probability: `0` to `1` inclusive, where `0.15` is a fifteen percent chance.
///
/// The range states the convention, so unlike [Percentage] there is no unit to get wrong and one
/// door is enough.
///
/// > [!NOTE]
/// > **Both ends are included.** An impossible event has probability `0` and a certain one `1`, and
/// > an empirical `0/n` lands on the first legitimately. [isImpossible] and [isCertain] report them
/// > rather than the range refusing them. Why: `APPENDIX.md#probability-constraint-type`.
///
/// [value] is the numeric value; the string form is `value.toString()`.
///
/// {@example /example/minted_constraints_example.dart#probability}
extension type const Probability._(double value) implements double {
  /// The [Probability] with numeric [value], or `null` unless it is `0` to `1`. A `NaN` is out of
  /// range, since the bound is written as a positive test.
  static Probability? tryFrom(num value) =>
      value >= _impossible && value <= _certain ? ._(positiveZeroed(value.toDouble())) : null;

  /// The [Probability] equal to [percentage], or `null` when it sits outside `0`-`100`. Partial
  /// where [toPercentage] is total, because a [Percentage] is unbounded.
  static Probability? tryFromPercentage(Percentage percentage) => tryFrom(percentage.fraction);

  /// This probability as a [Percentage]: `0.15` is 15%. Total, since every probability is one.
  // In range and finite, so the fraction door cannot refuse it.
  Percentage toPercentage() => Percentage.tryFromFraction(value)!;

  /// The probability of this *not* happening. Always in range, so it never fails, but not exactly
  /// involutive: doubles make `0.3`'s double complement `0.30000000000000004`.
  /// Why: `APPENDIX.md#probability-constraint-type`.
  Probability get complement => ._(_certain - value);

  /// Whether the event cannot happen: exactly `0`.
  bool get isImpossible => value == _impossible;

  /// Whether the event must happen: exactly `1`.
  bool get isCertain => value == _certain;

  static const double _impossible = 0;
  static const double _certain = 1;
}
