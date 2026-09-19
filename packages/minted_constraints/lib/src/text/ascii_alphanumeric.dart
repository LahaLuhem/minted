import 'ascii_char.dart';

/// Exactly one ASCII letter or digit, `A`-`Z`, `a`-`z` or `0`-`9`.
///
/// The charset ISO 9362 and the IBAN registry fix for their code parts, so that's what those parts take
/// instead of a `String` that would also admit punctuation and spaces.
///
/// {@example /example/minted_constraints_example.dart#ascii}
extension type const AsciiAlphanumeric._(String value) implements AsciiChar {
  /// The [AsciiAlphanumeric] spelled by [value], or `null` unless it's one letter or digit.
  static AsciiAlphanumeric? tryFrom(String value) =>
      !_alphanumeric.hasMatch(value) ? null : ._(value);

  static final _alphanumeric = RegExp(r'^[A-Za-z0-9]$');
}
