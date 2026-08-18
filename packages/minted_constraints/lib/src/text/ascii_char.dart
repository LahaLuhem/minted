/// @docImport 'ascii_letter.dart';
library;

/// Exactly one ASCII character, as a `String` of a single code unit below `0x80`.
///
/// The bug this deletes is a "one character" slot typed as `String`, which accepts none and accepts
/// twenty. Where only a letter belongs, reach for [AsciiLetter].
///
/// Control characters are admitted rather than refused: a delimiter or a padding character is often
/// one, and `\t` is a character by any reading. [isControl] reports the narrower shape instead.
///
/// [value] is the character itself, so the string form needs no getter.
///
/// {@example /example/minted_constraints_example.dart#ascii}
extension type const AsciiChar._(String value) {
  /// The [AsciiChar] spelled by [value], or `null` unless it is exactly one ASCII character.
  // One code unit below 0x80 cannot be half a surrogate pair, so a length of 1 is a whole character.
  static AsciiChar? tryFrom(String value) =>
      value.length == 1 && value.codeUnitAt(0) < _asciiCeiling ? ._(value) : null;

  /// Whether this is a C0 control character or `DEL`, which [tryFrom] accepts but a rendered slot
  /// will not show.
  bool get isControl => value.codeUnitAt(0) < _firstPrintable || value.codeUnitAt(0) == _delete;

  static const _asciiCeiling = 0x80;
  static const _firstPrintable = 0x20;
  static const _delete = 0x7f;
}
