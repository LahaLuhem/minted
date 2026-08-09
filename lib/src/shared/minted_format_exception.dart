import 'minted_failure.dart';

/// The [FormatException] raised when a `minted` value type fails to parse.
///
/// It extends [FormatException] so existing `on FormatException` handlers catch it too, exactly as
/// they would for `int.parse` or `Uri.parse`. Catch [MintedFormatException] specifically to handle
/// only this package's parse failures. It carries the offending [source], same as the base type,
/// and the typed [failure] describing what went wrong.
class MintedFormatException extends FormatException {
  /// Why the parse failed, in the offending type's own vocabulary. Switch on it to react to a
  /// specific cause; [message] is the same thing rendered.
  final MintedFailure failure;

  const MintedFormatException._(this.failure, super.message, super.source);

  /// Builds the exception a value type throws on invalid input, rendering [failure] into a
  /// `Invalid <typeName>: <message>` [message] over the offending [source].
  factory MintedFormatException.from(MintedFailure failure, String source) =>
      MintedFormatException._(failure, 'Invalid ${failure.typeName}: ${failure.message}', source);
}
