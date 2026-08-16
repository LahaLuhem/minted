/// @docImport '../iso8601_duration.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/outcomes/minted_failure.dart';

/// Why an [Iso8601Duration] refused its input. Sealed, not an enum, because three variants carry
/// the part that broke.
@immutable
sealed class Iso8601DurationFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Iso8601Duration';
}

/// The text is not a `P`-prefixed duration at all.
final class Iso8601DurationMalformed extends Iso8601DurationFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'not an ISO 8601 duration (expected PnYnMnDTnHnMnS or PnW)';

  @override
  bool operator ==(Object other) => other is Iso8601DurationMalformed;

  @override
  int get hashCode => (Iso8601DurationMalformed).hashCode;

  @override
  String toString() => 'Iso8601DurationMalformed()';
}

/// `P` or `PT` with nothing after it. ISO 8601 requires at least one component, so a zero duration
/// is written `PT0S` rather than `P`.
final class Iso8601DurationEmpty extends Iso8601DurationFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'has no components; a zero duration is "PT0S", not "P"';

  @override
  bool operator ==(Object other) => other is Iso8601DurationEmpty;

  @override
  int get hashCode => (Iso8601DurationEmpty).hashCode;

  @override
  String toString() => 'Iso8601DurationEmpty()';
}

/// Weeks appeared beside another component. ISO 8601 makes `PnW` an alternative to
/// `PnYnMnDTnHnMnS`, not a component of it, so the two never mix.
final class Iso8601DurationWeeksNotAlone extends Iso8601DurationFailure {
  /// The component found alongside the weeks, as its ISO designator: `Y`, `M`, `D`, `H` or `S`.
  final String designator;

  /// Creates the failure.
  const new(this.designator);

  @override
  String get message => 'the week form PnW cannot carry a "$designator" component too';

  @override
  bool operator ==(Object other) =>
      other is Iso8601DurationWeeksNotAlone && other.designator == designator;

  @override
  int get hashCode => Object.hash(Iso8601DurationWeeksNotAlone, designator);

  @override
  String toString() => 'Iso8601DurationWeeksNotAlone($designator)';
}

/// A `T` with no time component after it, as in `P1DT`. The designator exists to separate months
/// from minutes, so it means nothing on its own.
final class Iso8601DurationDanglingTimeDesignator extends Iso8601DurationFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'has a T with no time component after it';

  @override
  bool operator ==(Object other) => other is Iso8601DurationDanglingTimeDesignator;

  @override
  int get hashCode => (Iso8601DurationDanglingTimeDesignator).hashCode;

  @override
  String toString() => 'Iso8601DurationDanglingTimeDesignator()';
}

/// A fraction sat above the smallest component present. ISO 8601 allows one only on the
/// lowest-order component, so `P0.5Y1M` is refused where `P1Y0.5M` is not.
final class Iso8601DurationFractionNotSmallest extends Iso8601DurationFailure {
  /// The designator carrying the fraction.
  final String designator;

  /// Creates the failure.
  const new(this.designator);

  @override
  String get message =>
      'only the smallest component may be fractional, and "$designator" is not it';

  @override
  bool operator ==(Object other) =>
      other is Iso8601DurationFractionNotSmallest && other.designator == designator;

  @override
  int get hashCode => Object.hash(Iso8601DurationFractionNotSmallest, designator);

  @override
  String toString() => 'Iso8601DurationFractionNotSmallest($designator)';
}
