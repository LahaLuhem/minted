import 'dart:math';

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

import 'date.dart';
import 'failures/iso8601_duration_failure.dart';
import 'month.dart';

part 'constants/iso8601_duration_constants.dart';
part 'helpers/iso8601_duration_helpers.dart';

/// An ISO 8601 duration: `P3Y6M4DT12H30M5S`, or the week form `P2W`.
/// Standard: [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601#Durations).
///
/// `dart:core`'s [Duration] can't express months or years, nor read this format. This holds components
/// rather than one scalar, because a month has no length until anchored.
///
/// > [!NOTE]
/// > `P1M` is one month and `PT1M` is one minute. The `T` is what separates them, so it is required
/// > before a time component and refused without one.
///
/// The week form is exclusive, so `P1Y2W` is refused, and at least one component is needed, so `PT0S`
/// is the zero duration and `P` is not. Only the smallest component may carry a [fraction], and a negative
/// duration is refused, ISO 8601-1 having no sign.
///
/// Parsing turns a decimal comma into a point and collapses zero components, so `P1Y0M` and `P1Y` are
/// one value. [iso8601] is the canonical form.
///
/// Named values: [Iso8601DurationConstants].
///
/// {@example /example/minted_chronology_example.dart#iso8601Duration}
@immutable
final class const Iso8601Duration._({
  /// Whole years.
  required final int years,

  /// Whole months.
  required final int months,

  /// Whole weeks. Non-zero only in the week form, where every other component is zero.
  required final int weeks,

  /// Whole days.
  required final int days,

  /// Whole hours.
  required final int hours,

  /// Whole minutes.
  required final int minutes,

  /// Whole seconds.
  required final int seconds,

  /// The fractional part and the component carrying it, or `null` when the duration is whole. Always
  /// the smallest component present, ISO 8601 allowing a fraction nowhere else.
  required final ({Iso8601DurationComponent component, double value})? fraction,
}) {
  /// Parses [input], or `null` if it isn't an ISO 8601 duration.
  static Iso8601Duration? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [Iso8601DurationFailure] saying which rule broke.
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
  /// The anchor is needed because a month is 28 to 31 days. Calendar components go first, clamping the
  /// day the way `2026-01-31` plus a month gives `2026-02-28`. A [fraction] on one of them scales that
  /// component's real length there.
  Duration toDuration({required Date from}) {
    final monthIndex = from.month.value - 1 + years * _monthsPerYear + months;
    final anchoredYear = from.year + monthIndex ~/ _monthsPerYear;
    // The modulo pins the index to 1-12, so tryFrom cannot return null here.
    final anchoredMonth = Month.tryFrom(monthIndex % _monthsPerYear + 1)!;
    // Asserts, as it did before: an anchor past 9999 throws rather than silently clamping.
    final anchored = Date.of(
      anchoredYear,
      anchoredMonth.value,
      min(from.day, anchoredMonth.daysIn(anchoredYear)),
    ).getOrThrow();

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
}

/// Which component of an [Iso8601Duration] carries its fractional part.
enum Iso8601DurationComponent() {
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
