import 'minted_failure.dart';

/// The [FormatException] raised when a `minted` value type fails to parse.
///
/// It extends [FormatException] so existing `on FormatException` handlers catch it too, exactly as
/// they would for `int.parse` or `Uri.parse`. Catch [MintedFormatException] specifically to handle
/// only this package's parse failures. It carries the offending [source], same as the base type,
/// and the typed [failure] describing what went wrong.
class MintedFormatException extends FormatException {
  /// Why the parse failed, as the offending type's own failure vocabulary.
  ///
  /// Switch on it to react to a specific cause; the exception's [message] is the rendered form of
  /// the same thing, for when a string is all you need.
  final MintedFailure failure;

  const MintedFormatException._(this.failure, super.message, super.source);

  /// Builds the exception a value type throws on invalid input.
  ///
  /// [failure] is the typed reason and [source] the offending input; the [message] reads
  /// `Invalid <typeName>: <message>`, both taken from [failure].
  factory MintedFormatException.from(MintedFailure failure, String source) =>
      MintedFormatException._(failure, 'Invalid ${failure.typeName}: ${failure.message}', source);
}
