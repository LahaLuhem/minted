part of '../iso8601_duration.dart';

/// The zero [Iso8601Duration], and the one ISO 8601 write-ups walk through.
abstract final class Iso8601DurationConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The zero duration. ISO 8601 needs at least 1 component, so it is written `PT0S` rather than
  /// bare `P`.
  static const zero = Iso8601Duration._(
    years: 0,
    months: 0,
    weeks: 0,
    days: 0,
    hours: 0,
    minutes: 0,
    seconds: 0,
    fraction: null,
  );

  /// The duration ISO 8601 write-ups walk through, carrying every component at once.
  static const example = Iso8601Duration._(
    years: 3,
    months: 6,
    weeks: 0,
    days: 4,
    hours: 12,
    minutes: 30,
    seconds: 5,
    fraction: null,
  );
}
