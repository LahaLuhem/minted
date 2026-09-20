part of '../date.dart';

// The parts of an ISO 8601 YYYY-MM-DD string, or null when the input isn't that shape.
({int year, int month, int day})? _partsOf(String input) {
  final iso8601Match = _iso8601.firstMatch(input);

  return iso8601Match == null
      ? null
      : (
          year: int.parse(iso8601Match.group(1)!),
          month: int.parse(iso8601Match.group(2)!),
          day: int.parse(iso8601Match.group(3)!),
        );
}

// The one gate parse, the factory and fromDateTime all go through.
Date? _tryFromParts(int year, int month, int day) {
  final parsedMonth = Month.tryFrom(month);
  if (parsedMonth == null) return null;

  final wellFormed =
      year >= _minYear && year <= _maxYear && day >= 1 && day <= parsedMonth.daysIn(year);

  return !wellFormed ? null : Date._(year, parsedMonth, day);
}

// Which part of the given date is out of range. Reached only after _tryFromParts returns null, so
// exactly one of these conditions holds.
DateComponentFailure _partsFailure(int year, int month, int day) {
  if (year < _minYear || year > _maxYear) return DateYearOutOfRange(year);

  final parsedMonth = Month.tryFrom(month);

  return parsedMonth == null
      ? DateMonthOutOfRange(month)
      : DateDayOutOfRange(year: year, month: month, day: day, maxDay: parsedMonth.daysIn(year));
}

final _iso8601 = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

const _minYear = 0;
const _maxYear = 9999;
