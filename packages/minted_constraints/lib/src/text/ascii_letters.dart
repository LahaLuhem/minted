import 'ascii_letter.dart';

/// One or more [AsciiLetter]s.
///
/// {@example /example/minted_constraints_example.dart#plurals}
extension type const AsciiLetters._(String value) implements String {
  /// The [AsciiLetters] spelled by [value], or `null` unless it is all ASCII letters.
  static AsciiLetters? tryFrom(String value) => !_letters.hasMatch(value) ? null : ._(value);

  /// The letters, one per code unit.
  // tryFrom's gate already passed every code unit.
  Iterable<AsciiLetter> get letters =>
      Iterable.generate(value.length, (index) => AsciiLetter.tryFrom(value[index])!);

  static final _letters = RegExp(r'^[A-Za-z]+$');
}
