import 'ascii_alphanumeric.dart';

/// One or more [AsciiAlphanumeric]s: a `Bic` code, an IBAN's BBAN, an ISIN's NSIN.
///
/// {@example /example/minted_constraints_example.dart#plurals}
extension type const AsciiAlphanumerics._(String value) implements String {
  /// The [AsciiAlphanumerics] spelled by [value], or `null` unless it is all letters and digits.
  static AsciiAlphanumerics? tryFrom(String value) =>
      !_alphanumerics.hasMatch(value) ? null : ._(value);

  /// The characters, one per code unit.
  // tryFrom's gate already passed every code unit.
  Iterable<AsciiAlphanumeric> get alphanumerics =>
      Iterable.generate(value.length, (index) => AsciiAlphanumeric.tryFrom(value[index])!);

  static final _alphanumerics = RegExp(r'^[A-Za-z0-9]+$');
}
