import '../../shared/normalisation/normalisation.dart';

const _yearWidth = 4;
const _fieldWidth = 2;

/// The ISO 8601 calendar-date form of [year], [month], and [day]: `YYYY-MM-DD`, zero-padded.
String isoDate(int year, int month, int day) =>
    '${isoYearMonth(year, month)}-${_pad(day, _fieldWidth)}';

/// The year-and-month head of an [isoDate]: `YYYY-MM`, zero-padded.
String isoYearMonth(int year, int month) => '${_pad(year, _yearWidth)}-${_pad(month, _fieldWidth)}';

String _pad(int value, int width) => value.toString().padLeft(width, zeroPad);
