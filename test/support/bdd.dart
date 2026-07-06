/// A thin, zero-dependency Gherkin vocabulary over `package:test`.
///
/// The value is the shape, not a framework: [feature] and [scenario] make the
/// system under test and its expected behaviour read as a specification, and
/// [scenarioOutline] drives one system under test from a table of named
/// examples, so the input values stay grouped as clear parameters instead of
/// scattered through the test body.
library;

import 'dart:async';

import 'package:test/test.dart';

/// Groups the scenarios describing one unit under test. Reads as
/// `Feature: <description>` in the test output.
void feature(String description, void Function() body) => group('Feature: $description', body);

/// One behaviour of the unit under test, as a single test. Reads as
/// `Scenario: <description>`; [body] is the Given/When/Then flow.
void scenario(String description, FutureOr<void> Function() body) =>
    test('Scenario: $description', body);

/// A scenario exercised once per row of an examples table.
///
/// [examples] maps each row's name (what makes the case interesting) to its
/// data: a record grouping the input parameters with the expected outcome, so
/// the cases read as a table rather than scattered literals. [outline] receives
/// each row and exercises the system under test, and becomes one test per row,
/// so a failure names the row that broke.
void scenarioOutline<Row>(
  String description, {
  required Map<String, Row> examples,
  required FutureOr<void> Function(Row example) outline,
}) => group('Scenario Outline: $description', () {
  for (final MapEntry(key: name, value: row) in examples.entries) {
    test(name, () => outline(row));
  }
});
