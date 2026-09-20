// ignore_for_file: prefer-match-file-name

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Stand-in failure vocabularies for exercising core's outcome machinery.
///
/// Core declares [MintedFailure] but no concrete variant: every real vocabulary belongs to a domain
/// package. These let core test its own `ParseOutcome` and `MintedFormatError` without depending on
/// a package that depends on it.
enum TestFailure(@override final String message) implements MintedFailure {
  /// A failure whose rendering the format-error tests assert against.
  malformed('not a well-formed test value');

  @override
  String get typeName => 'TestValue';
}

/// A second vocabulary, for the cases that need 2 unrelated failures.
@immutable
final class const OtherFailure() implements MintedFailure {
  @override
  String get typeName => 'OtherValue';

  @override
  String get message => 'failed the other check';

  @override
  bool operator ==(Object other) => other is OtherFailure;

  @override
  int get hashCode => (OtherFailure).hashCode;
}
