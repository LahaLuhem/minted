import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Weekday', () {
    // The ISO day number round-trips through value; null means out of range.
    scenarioOutline<({int input, Weekday? day})>(
      'Weekday.tryFrom accepts ISO day numbers 1-7 and rejects the rest',
      examples: {
        'the first day': (input: 1, day: Weekday.monday),
        'a midweek day': (input: 3, day: Weekday.wednesday),
        'the last day': (input: 7, day: Weekday.sunday),
        'day zero': (input: 0, day: null),
        'day eight': (input: 8, day: null),
        'a negative day': (input: -1, day: null),
      },
      outline: (example) {
        check(Weekday.tryFrom(example.input)).equals(example.day);
      },
    );

    // plusDays walks the cycle, so it lands on a weekday for any offset.
    scenarioOutline<({Weekday from, int days, Weekday landsOn})>(
      'Weekday.plusDays wraps round the week in both directions',
      examples: {
        'a step inside the week': (from: Weekday.monday, days: 2, landsOn: Weekday.wednesday),
        'a step over the end': (from: Weekday.saturday, days: 2, landsOn: Weekday.monday),
        'a step back over the start': (from: Weekday.monday, days: -1, landsOn: Weekday.sunday),
        'a whole week': (from: Weekday.thursday, days: 7, landsOn: Weekday.thursday),
        'no move at all': (from: Weekday.thursday, days: 0, landsOn: Weekday.thursday),
        'many weeks forward': (from: Weekday.tuesday, days: 700, landsOn: Weekday.tuesday),
        'many weeks back': (from: Weekday.tuesday, days: -703, landsOn: Weekday.saturday),
      },
      outline: (example) {
        check(example.from.plusDays(example.days)).equals(example.landsOn);
      },
    );

    // daysUntil counts forward round the cycle, so it never goes negative.
    scenarioOutline<({Weekday from, Weekday to, int days})>(
      'Weekday.daysUntil counts forward round the week, 0-6',
      examples: {
        'forward inside the week': (from: Weekday.monday, to: Weekday.thursday, days: 3),
        'across the week end': (from: Weekday.friday, to: Weekday.monday, days: 3),
        'the same day': (from: Weekday.friday, to: Weekday.friday, days: 0),
        'the full cycle less one': (from: Weekday.monday, to: Weekday.sunday, days: 6),
      },
      outline: (example) {
        check(example.from.daysUntil(example.to)).equals(example.days);
      },
    );

    scenario('the named values carry their ISO day number', () {
      check(Weekday.monday.value).equals(1);
      check(Weekday.sunday.value).equals(7);
      check(Weekday.values.length).equals(7);
    });

    scenario('value is the ISO day number, one more than the enum index', () {
      check(Weekday.monday.value).equals(Weekday.monday.index + 1);
      check(Weekday.sunday.value).equals(Weekday.sunday.index + 1);
    });

    scenario('tryFrom rejects a day number outside 1-7', () {
      check(Weekday.tryFrom(0)).isNull();
      check(Weekday.tryFrom(8)).isNull();
    });

    scenario('next and previous wrap at the ends of the week', () {
      check(Weekday.monday.next).equals(Weekday.tuesday);
      check(Weekday.sunday.next).equals(Weekday.monday);
      check(Weekday.monday.previous).equals(Weekday.sunday);
      check(Weekday.wednesday.minusDays(2)).equals(Weekday.monday);
    });

    scenario('a switch over a weekday is exhaustive without a default arm', () {
      final label = switch (Weekday.saturday) {
        .monday || .tuesday || .wednesday || .thursday || .friday => 'ISO working day',
        .saturday || .sunday => 'ISO week end',
      };

      check(label).equals('ISO week end');
    });

    scenario('ordering follows the ISO week, Monday first', () {
      check(Weekday.monday < Weekday.sunday).isTrue();
      check(Weekday.sunday > Weekday.saturday).isTrue();
      // Comparing a day with itself is the point: >= must hold on the boundary.
      // ignore: avoid-self-compare
      check(Weekday.friday >= Weekday.friday).isTrue();
      check(Weekday.friday <= Weekday.saturday).isTrue();
      check(Weekday.monday.compareTo(Weekday.sunday)).isLessThan(0);
    });

    scenario('sorting orders Monday through Sunday', () {
      final days = [Weekday.sunday, Weekday.wednesday, Weekday.monday]..sort();

      check(days).deepEquals([Weekday.monday, Weekday.wednesday, Weekday.sunday]);
    });
  });
}
