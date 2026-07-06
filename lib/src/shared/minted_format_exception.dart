/// The [FormatException] raised when a `minted` value type fails to parse.
///
/// It extends [FormatException] so existing `on FormatException` handlers catch it too, exactly as
/// they would for `int.parse` or `Uri.parse`. Catch [MintedFormatException] specifically to handle
/// only this package's parse failures. It carries the offending [source], same as the base type.
class MintedFormatException extends FormatException {
  const MintedFormatException._(super.message, super.source);

  /// Builds the exception a value type's `parse` throws on invalid input.
  ///
  /// [typeName] is the value type's name (e.g. `'Iban'`), [source] the offending input, and [reason]
  /// what failed; the [message] reads `Invalid <typeName>: <reason>`.
  ///
  /// [typeName] is an explicit string, not a `<T>`, because the value types are extension types:
  /// they erase to their representation at runtime, so `'$T'` would render `String` rather than the type's name.
  factory MintedFormatException.of(String typeName, String source, String reason) =>
      MintedFormatException._('Invalid $typeName: $reason', source);
}
