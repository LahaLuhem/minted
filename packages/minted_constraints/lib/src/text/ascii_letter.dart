import 'ascii_char.dart';
import 'letter.dart';

/// Exactly one ASCII letter, `A`-`Z` or `a`-`z`.
///
/// An [AsciiChar] and a [Letter] narrowed to what the standards-bound codes admit. Case is kept, not
/// folded: only a standard that says so may fold `Q` onto `q`.
///
/// {@example /example/minted_constraints_example.dart#ascii}
extension type const AsciiLetter._(String value) implements AsciiChar, Letter {
  /// The [AsciiLetter] spelled by [value], or `null` unless it is exactly one ASCII letter.
  static AsciiLetter? tryFrom(String value) => _letter.hasMatch(value) ? ._(value) : null;

  static final _letter = RegExp(r'^[A-Za-z]$');
}
