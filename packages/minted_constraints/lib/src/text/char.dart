/// @docImport 'ascii_char.dart';
/// @docImport 'letter.dart';
library;

import 'package:characters/characters.dart';

/// Exactly one character as a reader sees it: one Unicode grapheme cluster.
///
/// Not one code unit or code point: a skin-toned thumbs-up is two code points, a flag two, a joined
/// family five, and each fills one slot. `length == 1` refuses all three and admits half a surrogate
/// pair, which this refuses instead.
///
/// Control characters are admitted, as on [AsciiChar]. Where only a letter belongs, use [Letter].
///
/// {@example /example/minted_constraints_example.dart#char}
// Does not implement String, unlike the Ascii types: a grapheme can span two code units, so
// `length` would answer 2. Letter and Letters are opaque for the same reason.
extension type const Char._(String value) {
  /// The [Char] spelled by [value], or `null` unless it is exactly one character.
  static Char? tryFrom(String value) =>
      value.characters.length != 1 || _hasUnpairedSurrogate(value) ? null : ._(value);

  // A surrogate pair decodes to one rune above the range, so a rune inside it was never paired.
  static bool _hasUnpairedSurrogate(String value) =>
      value.runes.any((rune) => rune >= _surrogateFirst && rune <= _surrogateLast);

  static const _surrogateFirst = 0xD800;
  static const _surrogateLast = 0xDFFF;
}
