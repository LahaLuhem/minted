/// @docImport 'ascii_char.dart';
library;

import 'ascii_char.dart';

/// Exactly one ASCII letter, `A`-`Z` or `a`-`z`.
///
/// An [AsciiChar] narrowed to what the standards-bound codes admit, so it is one wherever one is
/// wanted. Case is kept, not folded: `Q` and `q` are different letters, and only a standard that
/// says otherwise may fold them.
///
/// [value] is the letter itself, so the string form needs no getter.
///
/// {@example /example/minted_constraints_example.dart#ascii}
extension type const AsciiLetter._(String value) implements AsciiChar {
  /// The [AsciiLetter] spelled by [value], or `null` unless it is exactly one ASCII letter.
  static AsciiLetter? tryFrom(String value) => _letter.hasMatch(value) ? ._(value) : null;

  static final _letter = RegExp(r'^[A-Za-z]$');
}
