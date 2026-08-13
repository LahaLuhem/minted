import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Iso8601Duration', () {
    // The canonical form doubles as the outcome; null means the input was rejected.
    scenarioOutline<({String input, String? iso8601})>(
      'Iso8601Duration.tryParse accepts the ISO 8601 grammar and normalises it',
      examples: {
        'every component': (input: 'P3Y6M4DT12H30M5S', iso8601: 'P3Y6M4DT12H30M5S'),
        'the week form alone': (input: 'P2W', iso8601: 'P2W'),
        'a month, not a minute': (input: 'P1M', iso8601: 'P1M'),
        'a minute, not a month': (input: 'PT1M', iso8601: 'PT1M'),
        'zero spells itself': (input: 'PT0S', iso8601: 'PT0S'),
        'any other zero collapses to it': (input: 'P0D', iso8601: 'PT0S'),
        'absent and zero components collapse': (input: 'P1Y0M', iso8601: 'P1Y'),
        'a decimal comma folds to a point': (input: 'P1,5D', iso8601: 'P1.5D'),
        'a fraction on the only component': (input: 'P0.5Y', iso8601: 'P0.5Y'),
        'a fraction on the smallest present': (input: 'P1Y0.5M', iso8601: 'P1Y0.5M'),
        'surrounding whitespace is trimmed': (input: '  P1D  ', iso8601: 'P1D'),
      },
      outline: (example) {
        check(Iso8601Duration.tryParse(example.input)?.iso8601).equals(example.iso8601);
      },
    );

    // Each rule the grammar can distinguish gets its own reason, so a caller can say what to fix.
    scenarioOutline<({String input, Iso8601DurationFailure reason})>(
      'parse names the rule that broke',
      examples: {
        'not a duration at all': (input: 'hello', reason: const Iso8601DurationMalformed()),
        'a lone P has no components': (input: 'P', reason: const Iso8601DurationEmpty()),
        'nor does a lone PT': (input: 'PT', reason: const Iso8601DurationEmpty()),
        'a T needs a time component': (
          input: 'P1DT',
          reason: const Iso8601DurationDanglingTimeDesignator(),
        ),
        'seconds without the T': (input: 'P1S', reason: const Iso8601DurationMalformed()),
        'components out of order': (input: 'P1DT2Y', reason: const Iso8601DurationMalformed()),
        'a sign, which ISO 8601-1 has no room for': (
          input: '-P1D',
          reason: const Iso8601DurationMalformed(),
        ),
        'weeks beside years': (input: 'P1Y2W', reason: const Iso8601DurationWeeksNotAlone('Y')),
        'weeks beside days': (input: 'P2W3D', reason: const Iso8601DurationWeeksNotAlone('D')),
        'weeks beside a time component': (
          input: 'P2WT1H',
          reason: const Iso8601DurationWeeksNotAlone('H'),
        ),
        'weeks beside seconds': (input: 'P2WT1S', reason: const Iso8601DurationWeeksNotAlone('S')),
        'a fraction above the smallest': (
          input: 'P0.5Y1M',
          reason: const Iso8601DurationFractionNotSmallest('Y'),
        ),
        'a fraction above the smallest, in the time half': (
          input: 'PT1.5M30S',
          reason: const Iso8601DurationFractionNotSmallest('M'),
        ),
      },
      outline: (example) {
        check(Iso8601Duration.parse(example.input).reasonOrNull).equals(example.reason);
      },
    );

    scenario('components read back individually', () {
      final duration = Iso8601Duration.tryParse('P3Y6M4DT12H30M5S')!;

      check(duration.years).equals(3);
      check(duration.months).equals(6);
      check(duration.days).equals(4);
      check(duration.hours).equals(12);
      check(duration.minutes).equals(30);
      check(duration.seconds).equals(5);
      check(duration.weeks).equals(0);
      check(duration.fraction).isNull();
    });

    scenario('the fraction names the component carrying it', () {
      check(Iso8601Duration.tryParse('PT1.5S')!.fraction)
          .equals((component: Iso8601DurationComponent.seconds, value: 0.5));
      check(Iso8601Duration.tryParse('P0.5Y')!.fraction?.component)
          .equals(Iso8601DurationComponent.years);
    });

    // A month has no length until anchored, which is the whole reason `from` is required.
    scenarioOutline<({String input, Date from, Duration expected})>(
      'toDuration resolves calendar components against the anchor',
      examples: {
        'a month from a 31-day month clamps the day': (
          input: 'P1M',
          from: Date(2026, 1, 31),
          expected: const Duration(days: 28),
        ),
        'the same month is 31 days from March': (
          input: 'P1M',
          from: Date(2026, 3),
          expected: const Duration(days: 31),
        ),
        'a leap February is 29 days': (
          input: 'P1M',
          from: Date(2024, 2),
          expected: const Duration(days: 29),
        ),
        'a year across a leap day': (
          input: 'P1Y',
          from: Date(2024),
          expected: const Duration(days: 366),
        ),
        'weeks are exact': (input: 'P2W', from: Date(2026), expected: const Duration(days: 14)),
        'time components need no calendar': (
          input: 'PT12H30M5S',
          from: Date(2026),
          expected: const Duration(hours: 12, minutes: 30, seconds: 5),
        ),
        'a fractional second becomes microseconds': (
          input: 'PT1.5S',
          from: Date(2026),
          expected: const Duration(seconds: 1, milliseconds: 500),
        ),
        // A fraction on a calendar component scales that component's real length at the anchor,
        // so half a leap year is half a day longer than half a common one.
        'half a common year': (
          input: 'P0.5Y',
          from: Date(2026),
          expected: const Duration(hours: 365 * 12),
        ),
        'half a leap year': (
          input: 'P0.5Y',
          from: Date(2024),
          expected: const Duration(hours: 366 * 12),
        ),
      },
      outline: (example) {
        check(Iso8601Duration.tryParse(example.input)!.toDuration(from: example.from))
            .equals(example.expected);
      },
    );

    scenario('equal durations are equal by value and hash together', () {
      final parsed = Iso8601Duration.tryParse('P1Y2M3D')!;
      final twin = Iso8601Duration.tryParse('P1Y2M3D')!;

      check(parsed).equals(twin);
      check(parsed.hashCode).equals(twin.hashCode);
      check(parsed == Iso8601Duration.tryParse('P1Y2M4D')!).isFalse();
    });

    scenario('toString wraps the canonical form', () {
      check(Iso8601Duration.tryParse('P1,5D')!.toString()).equals('Iso8601Duration(P1.5D)');
    });
  });
}
