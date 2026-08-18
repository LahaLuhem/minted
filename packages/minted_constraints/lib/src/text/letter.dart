/// @docImport 'ascii_letter.dart';
library;

import 'char.dart';

/// Exactly one letter, in any script: one [Char] whose base rune is a Unicode letter.
///
/// So `Ø`, `Ł` and `Ж` qualify where [AsciiLetter] refuses them, a decomposed accent is one letter,
/// and an emoji is none.
///
/// {@example /example/minted_constraints_example.dart#char}
extension type const Letter._(String value) implements Char {
  /// The [Letter] spelled by [value], or `null` unless it is exactly one letter.
  // Derived from Char.tryFrom, so the two cannot disagree about what one character is.
  static Letter? tryFrom(String value) =>
      Char.tryFrom(value) != null && _startsWithLetter.hasMatch(value) ? ._(value) : null;

  static final _startsWithLetter = RegExp(r'^\p{L}', unicode: true);
}
