import 'package:characters/characters.dart';

import 'letter.dart';

/// One or more [Letter]s, in any script.
///
/// Over `String` rather than an `Iterable<Letter>`, because text is what this is; [letters] hands
/// back the elements.
///
/// {@example /example/minted_constraints_example.dart#plurals}
extension type const Letters._(String value) {
  /// The [Letters] spelled by [value], or `null` unless every character in it is a letter.
  static Letters? tryFrom(String value) =>
      !value.isNotEmpty || !value.characters.every(_isLetter) ? null : ._(value);

  /// The letters, one per character. Grapheme boundaries survive concatenation, so this splits back
  /// into exactly what built it.
  // tryFrom's gate already passed every character.
  Iterable<Letter> get letters => value.characters.map((character) => Letter.tryFrom(character)!);

  static bool _isLetter(String character) => Letter.tryFrom(character) != null;
}
