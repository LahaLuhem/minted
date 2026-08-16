/// @docImport 'parse_outcome.dart';
library;

import 'minted_failure.dart';

/// The error [ParseOutcome.getOrThrow] raises, carrying the typed [failure] and its rendered [message].
///
/// An [Error], because nothing throws at input: every fallible door reports its failure in the return
/// type. Reaching this means a caller asserted a value was valid and was wrong, which is a bug in
/// their source rather than a condition to catch.
class MintedFormatError extends Error {
  /// Why the value was refused, in the offending type's own vocabulary. Switch on it to react to a
  /// specific cause. [message] is the same thing rendered.
  final MintedFailure failure;

  /// The rendered `Invalid <typeName>: <message>` text.
  final String message;

  new _(this.failure, this.message);

  /// Builds the error from [failure], rendering it into an `Invalid <typeName>: <message>`.
  factory from(MintedFailure failure) =>
      MintedFormatError._(failure, 'Invalid ${failure.typeName}: ${failure.message}');

  @override
  String toString() => message;
}
