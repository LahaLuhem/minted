import 'ascii_alphanumeric.dart';
import 'letter.dart';

/// Exactly one ASCII letter, `A`-`Z` or `a`-`z`.
///
/// An [AsciiAlphanumeric] and a [Letter] narrowed to letters alone. Case is kept, not folded. Only a
/// standard that says so gets to fold `Q` onto `q`.
///
/// {@example /example/minted_constraints_example.dart#ascii}
extension type const AsciiLetter._(String value) implements AsciiAlphanumeric, Letter {
  /// The [AsciiLetter] spelled by [value], or `null` unless it's exactly one ASCII letter.
  static AsciiLetter? tryFrom(String value) => _letter.hasMatch(value) ? ._(value) : null;

  static final _letter = RegExp(r'^[A-Za-z]$');
}
