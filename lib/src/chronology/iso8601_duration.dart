import 'dart:math';

import 'package:meta/meta.dart';

import '../shared/outcomes/parse_outcome.dart';
import 'date.dart';
import 'failures/iso8601_duration_failure.dart';
import 'month.dart';

/// An ISO 8601 duration: `P3Y6M4DT12H30M5S`, or the week form `P2W`.
/// Standard: [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601#Durations).
///
/// Parse, don't validate: `dart:core`'s [Duration] cannot express months or years, nor read this
/// format. Holds components rather than one scalar, because a month has no length until anchored.
///
/// > [!NOTE]
/// > `P1M` is one month and `PT1M` is one minute. The `T` is what separates them, so it is required
/// > before a time component and refused without one.
///
/// The week form is exclusive, so `P1Y2W` is refused, and at least one component is required, so
/// `PT0S` is the zero duration and `P` is not. Only the smallest component may carry a [fraction].
/// Negative durations are refused: ISO 8601-1 has no sign.
///
/// Normalisation on parse: a decimal comma becomes a point and zero components collapse, so `P1Y0M`
/// and `P1Y` are one value. [iso8601] is the canonical form.
///
/// {@example /example/minted_example.dart#iso8601Duration}
@immutable
final class Iso8601Duration {
  /// Whole years.
  final int years;

  /// Whole months.
  final int months;

  /// Whole weeks. Non-zero only in the week form, where every other component is zero.
  final int weeks;

  /// Whole days.
  final int days;

  /// Whole hours.
  final int hours;

  /// Whole minutes.
  final int minutes;

  /// Whole seconds.
  final int seconds;

  /// The fractional part and the component carrying it, or `null` when the duration is whole.
  /// Always the smallest component present, since ISO 8601 allows a fraction nowhere else.
  final ({Iso8601DurationComponent component, double value})? fraction;

  const new _({
    required this.years,
    required this.months,
    required this.weeks,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.fraction,
  });

  /// Parses [input] as an ISO 8601 duration, or returns `null` when it is not one.
  /// See the type docs for the normalisation applied.
  static Iso8601Duration? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an ISO 8601 duration, reporting the [Iso8601DurationFailure] saying which
  /// rule broke.
  static ParseOutcome<Iso8601DurationFailure, Iso8601Duration> parse(String input) {
    // A decimal comma is ISO's preferred separator, so it folds to a point before matching.
    final match = _grammar.firstMatch(input.trim().replaceAll(',', '.'));
    if (match == null) return const ParseFailure(Iso8601DurationMalformed());

    // Group order follows the designators the grammar fixes: Y M W D then T H M S.
    final parts = <Iso8601DurationComponent, String?>{
      .years: match.group(1),
      .months: match.group(2),
      .weeks: match.group(3),
      .days: match.group(4),
      .hours: match.group(6),
      .minutes: match.group(7),
      .seconds: match.group(8),
    };
    final present = parts.entries.where((entry) => entry.value != null).toList(growable: false);
    if (present.isEmpty) return const ParseFailure(Iso8601DurationEmpty());

    final hasNoTimeParts = present.every((entry) => entry.key.index < _firstTimeComponent);
    if (match.group(5) != null && hasNoTimeParts) {
      return const ParseFailure(Iso8601DurationDanglingTimeDesignator());
    }

    final mixedWithWeeks = present.firstWhere(
      (entry) => entry.key != .weeks,
      orElse: () => present.first,
    );
    if (parts[Iso8601DurationComponent.weeks] != null && mixedWithWeeks.key != .weeks) {
      return ParseFailure(Iso8601DurationWeeksNotAlone(_designatorOf(mixedWithWeeks.key)));
    }

    final fractional = present.where((entry) => _hasFraction(entry.value!)).toList(growable: false);
    if (fractional.length > 1 || (fractional.isNotEmpty && fractional.single != present.last)) {
      return ParseFailure(Iso8601DurationFractionNotSmallest(_designatorOf(fractional.first.key)));
    }

    return ParseSuccess(Iso8601Duration._fromParts(parts, fractional.singleOrNull?.key));
  }

  /// The canonical text, `P3Y6M4DT12H30M5S`. Round-trips through [parse].
  String get iso8601 {
    // Every component collapses to nothing, and bare `P` is not a duration, so zero spells itself.
    if (_isZero) return 'PT0S';
    if (weeks != 0 || fraction?.component == .weeks) return 'P${_render(.weeks, weeks)}W';

    final date = _section(const {.years: 'Y', .months: 'M', .days: 'D'});
    final time = _section(const {.hours: 'H', .minutes: 'M', .seconds: 'S'});

    return time.isEmpty ? 'P$date' : 'P${date}T$time';
  }

  /// This duration as a [Duration], resolved against [from].
  ///
  /// The anchor is required because a month is 28 to 31 days. Calendar components go first,
  /// clamping the day the way `2026-01-31` plus a month gives `2026-02-28`; a [fraction] on one
  /// of them scales that component's real length there.
  Duration toDuration({required Date from}) {
    final monthIndex = from.month.value - 1 + years * _monthsPerYear + months;
    final anchoredYear = from.year + monthIndex ~/ _monthsPerYear;
    // The modulo pins the index to 1-12, so tryFrom cannot return null here.
    final anchoredMonth = Month.tryFrom(monthIndex % _monthsPerYear + 1)!;
    final anchored = Date.of(
      anchoredYear,
      anchoredMonth.value,
      min(from.day, anchoredMonth.daysIn(anchoredYear)),
    );

    final wholeDays = anchored.differenceInDays(from) + weeks * _daysPerWeek + days;
    final whole = Duration(days: wholeDays, hours: hours, minutes: minutes, seconds: seconds);

    return fraction == null ? whole : whole + _fractionAsDuration(anchored);
  }

  @override
  bool operator ==(Object other) =>
      other is Iso8601Duration &&
      other.years == years &&
      other.months == months &&
      other.weeks == weeks &&
      other.days == days &&
      other.hours == hours &&
      other.minutes == minutes &&
      other.seconds == seconds &&
      other.fraction == fraction;

  @override
  int get hashCode => Object.hash(years, months, weeks, days, hours, minutes, seconds, fraction);

  @override
  String toString() => 'Iso8601Duration($iso8601)';

  // The fraction's own component decides what it scales, and the calendar ones need the anchor.
  Duration _fractionAsDuration(Date anchored) {
    final part = fraction!;
    final unit = switch (part.component) {
      .years => Duration(days: _daysInYear(anchored.year)),
      .months => Duration(days: anchored.month.daysIn(anchored.year)),
      .weeks => const Duration(days: _daysPerWeek),
      .days => const Duration(days: 1),
      .hours => const Duration(hours: 1),
      .minutes => const Duration(minutes: 1),
      .seconds => const Duration(seconds: 1),
    };

    return Duration(microseconds: (unit.inMicroseconds * part.value).round());
  }

  String _section(Map<Iso8601DurationComponent, String> designators) => designators.entries
      .where((candidate) => _valueOf(candidate.key) != 0 || fraction?.component == candidate.key)
      .map((present) => '${_render(present.key, _valueOf(present.key))}${present.value}')
      .join();

  int _valueOf(Iso8601DurationComponent component) => switch (component) {
    .years => years,
    .months => months,
    .weeks => weeks,
    .days => days,
    .hours => hours,
    .minutes => minutes,
    .seconds => seconds,
  };

  String _render(Iso8601DurationComponent component, int whole) =>
      fraction?.component == component ? (whole + fraction!.value).toString() : '$whole';

  factory _fromParts(
    Map<Iso8601DurationComponent, String?> parts,
    Iso8601DurationComponent? fractionalComponent,
  ) {
    int whole(Iso8601DurationComponent component) {
      final text = parts[component];

      return text == null ? 0 : int.parse(text.split('.').first);
    }

    final fractionText = fractionalComponent == null ? null : parts[fractionalComponent]!;

    return Iso8601Duration._(
      years: whole(.years),
      months: whole(.months),
      weeks: whole(.weeks),
      days: whole(.days),
      hours: whole(.hours),
      minutes: whole(.minutes),
      seconds: whole(.seconds),
      fraction: fractionalComponent == null
          ? null
          : (
              component: fractionalComponent,
              value: double.parse('0.${fractionText!.split('.').last}'),
            ),
    );
  }

  bool get _isZero =>
      fraction == null &&
      Iso8601DurationComponent.values.every((component) => _valueOf(component) == 0);

  static bool _hasFraction(String value) => value.contains('.');

  static int _daysInYear(int year) => Date.of(year + 1).differenceInDays(Date.of(year));

  static String _designatorOf(Iso8601DurationComponent component) => switch (component) {
    .years => 'Y',
    .months => 'M',
    .weeks => 'W',
    .days => 'D',
    .hours => 'H',
    .minutes => 'M',
    .seconds => 'S',
  };

  static const _monthsPerYear = 12;
  static const _daysPerWeek = 7;

  /// Where the time half starts in [Iso8601DurationComponent]'s declaration order.
  static final _firstTimeComponent = Iso8601DurationComponent.hours.index;

  // Permissive about emptiness on purpose: `P` and `PT` match with no groups, so `parse` can name
  // the rule they broke rather than calling them malformed.
  static final _grammar = RegExp(
    r'^P(?:(\d+(?:\.\d+)?)Y)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)W)?'
    r'(?:(\d+(?:\.\d+)?)D)?'
    r'(?:(T)(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
  );
}

/// Which component of an [Iso8601Duration] carries its fractional part. Derived from a duration
/// that already parsed, so it is a classification rather than a value type: no parse door.
enum Iso8601DurationComponent {
  /// Years, designator `Y`.
  years,

  /// Months, designator `M` before the `T`.
  months,

  /// Weeks, designator `W`. Only ever the sole component.
  weeks,

  /// Days, designator `D`.
  days,

  /// Hours, designator `H`.
  hours,

  /// Minutes, designator `M` after the `T`.
  minutes,

  /// Seconds, designator `S`.
  seconds,
}
