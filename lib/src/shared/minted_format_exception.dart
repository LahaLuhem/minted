/// The [FormatException] raised when a `minted` value type fails to parse.
///
/// It extends [FormatException] so existing `on FormatException` handlers catch
/// it too, exactly as they would for `int.parse` or `Uri.parse`. Catch
/// [MintedFormatException] specifically to handle only this package's parse
/// failures. It carries the offending [source], same as the base type.
class MintedFormatException extends FormatException {
  const MintedFormatException._(super.message, super.source);

  /// Builds the exception thrown by `T.parse` when its input is invalid.
  ///
  /// [source] is the offending input and [reason] explains what failed (for
  /// example `'failed the mod-97 check'`); the resulting [message] reads
  /// `Invalid <T>: <reason>`.
  static MintedFormatException of<T>(String source, String reason) =>
      MintedFormatException._('Invalid $T: $reason', source);
}
