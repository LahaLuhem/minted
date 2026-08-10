/// @docImport 'minted_format_exception.dart';
library;

/// Why a `minted` value type refused its input.
///
/// Each value type declares its own failure vocabulary implementing this, sized to what its standard
/// can distinguish. Switch on that for user-facing text. This supertype is the generic handle, for
/// code spanning value types.
abstract interface class MintedFailure {
  /// The value type that refused the input, e.g. `'Iban'`. An explicit string, not a `<T>`, because
  /// extension types erase to their representation at runtime.
  String get typeName;

  /// What went wrong, e.g. `'failed the mod-97 check'`, for logs.
  ///
  /// Never names its own type: [MintedFormatException] already prefixes `Invalid <typeName>:`.
  String get message;
}
