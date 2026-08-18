/// @docImport 'ascii_letter.dart';
library;

import 'char.dart';

/// Exactly one ASCII character: a single code unit below `0x80`.
///
/// A "one character" slot typed as `String` accepts none and accepts twenty. Where only a letter
/// belongs, use [AsciiLetter].
///
/// Control characters are admitted rather than refused, a delimiter often being one; [isControl]
/// reports the narrower shape.
///
/// {@example /example/minted_constraints_example.dart#ascii}
extension type const AsciiChar._(String value) implements Char, String {
  /// The [AsciiChar] spelled by [value], or `null` unless it is exactly one ASCII character.
  // One code unit below 0x80 cannot be half a surrogate pair, so a length of 1 is a whole character.
  static AsciiChar? tryFrom(String value) =>
      value.length == 1 && value.codeUnitAt(0) < _asciiCeiling ? ._(value) : null;

  /// Whether this is a C0 control character or `DEL`: accepted, but nothing a slot will show.
  bool get isControl => value.codeUnitAt(0) < _firstPrintable || value.codeUnitAt(0) == _delete;

  static const _asciiCeiling = 0x80;
  static const _firstPrintable = 0x20;
  static const _delete = 0x7f;
}
