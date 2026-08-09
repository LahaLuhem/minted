/// @docImport 'minted_format_exception.dart';
library;

/// Why a `minted` value type refused to parse its input.
///
/// Every value type declares its own failure type implementing this one, so the vocabulary matches
/// what its standard can actually distinguish: a grammar has one way to fail, while a checksum plus
/// a registry has several. Switch on that per-type failure for user-facing text; this supertype is
/// the generic handle, for code that works across value types (a form validator, a logger) and has
/// nothing to switch on.
///
/// Deliberately not `sealed`: a sealed supertype would force every failure type into this one file
/// and rule out the enum half of the family. Cross-type exhaustiveness was never the goal, and
/// exhaustive switching works per type for enums and sealed classes alike.
abstract interface class MintedFailure {
  /// The value type that refused the input, e.g. `'Iban'`.
  ///
  /// An explicit string rather than a `<T>`, because the value types are extension types: they
  /// erase to their representation at runtime, so `'$T'` would render `String`, not `Iban`.
  String get typeName;

  /// What went wrong, e.g. `'failed the mod-97 check'`, for logs and debugging.
  ///
  /// Never names its own type: [MintedFormatException] renders `'Invalid $typeName: $message'`, so
  /// a message naming its type would stutter into `Invalid Iban: not a valid Iban`. For text shown
  /// to a user, switch on the failure itself and write the wording (and the translation) there.
  String get message;
}
