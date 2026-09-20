part of '../iso8601_duration.dart';

bool _hasFraction(String value) => value.contains('.');

int _daysInYear(int year) =>
    Date.of(year + 1).getOrThrow().differenceInDays(Date.of(year).getOrThrow());

String _designatorOf(Iso8601DurationComponent component) => switch (component) {
  .years => 'Y',
  .months => 'M',
  .weeks => 'W',
  .days => 'D',
  .hours => 'H',
  .minutes => 'M',
  .seconds => 'S',
};

const _monthsPerYear = 12;
const _daysPerWeek = 7;

/// Where the time half starts in [Iso8601DurationComponent]'s declaration order.
final _firstTimeComponent = Iso8601DurationComponent.hours.index;

// Permissive about emptiness on purpose: `P` and `PT` match with no groups, so `parse` can name the
// rule they broke rather than calling them malformed.
final _grammar = RegExp(
  r'^P(?:(\d+(?:\.\d+)?)Y)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)W)?'
  r'(?:(\d+(?:\.\d+)?)D)?'
  r'(?:(T)(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
);
