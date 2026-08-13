import '../shared/normalisation.dart';

/// A proportion in hundredths, where `15` is fifteen percent.
///
/// `15` or `0.15` for the same proportion is the bug this deletes: both readings are plausible and
/// neither is checkable at a call site. [tryFrom] takes the percent, [tryFromFraction] the
/// fraction, so a caller says which they hold.
///
/// > [!IMPORTANT]
/// > **Deliberately unbounded.** 250% growth and -12% churn are real values, so the only invariant
/// > is finiteness. Why: `APPENDIX.md#percentage-constraint-type`.
///
/// [value] is the percent; the string form is `value.toString()`.
///
/// {@example /example/minted_example.dart#percentage}
extension type const Percentage._(double value) {
  /// The [Percentage] of [percent] hundredths (`15` is fifteen percent), or `null` unless finite.
  static Percentage? tryFrom(num percent) =>
      percent.isFinite ? ._(positiveZeroed(percent.toDouble())) : null;

  /// The [Percentage] equal to [fraction] of the whole (`0.15` is fifteen percent), or `null`
  /// unless finite.
  static Percentage? tryFromFraction(num fraction) =>
      fraction.isFinite ? tryFrom(_hundredfold(fraction.toDouble())) : null;

  /// This percentage as a fraction of the whole: `0.15` for fifteen percent.
  double get fraction => value / _percentPerWhole;

  /// This percentage of [quantity]: fifteen percent `.of(200)` is `30`.
  double of(num quantity) => quantity * value / _percentPerWhole;

  // A decimal shift, not a multiply: `0.29 * 100` is 28.999999999999996. The non-finite guard runs
  // first, because a NaN has no exponent to bump. Why: `APPENDIX.md#percentage-constraint-type`.
  static double _hundredfold(double fraction) {
    final [mantissa, exponent] = fraction.toStringAsExponential().split('e');

    return double.parse('${mantissa}e${int.parse(exponent) + _percentDecimalShift}');
  }

  static const _percentPerWhole = 100;
  static const _percentDecimalShift = 2;
}
