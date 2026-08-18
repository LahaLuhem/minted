import 'ascii_alphanumeric.dart';

/// One or more [AsciiAlphanumeric]s: what `Bic`'s codes, an IBAN's BBAN and an ISIN's NSIN are made
/// of.
///
/// {@example /example/minted_constraints_example.dart#plurals}
extension type const AsciiAlphanumerics._(String value) {
  /// The [AsciiAlphanumerics] spelled by [value], or `null` unless it is all letters and digits.
  static AsciiAlphanumerics? tryFrom(String value) =>
      !_alphanumerics.hasMatch(value) ? null : ._(value);

  /// The characters, one per code unit.
  // Every code unit passed tryFrom's gate, so none can be refused here.
  Iterable<AsciiAlphanumeric> get alphanumerics =>
      Iterable.generate(value.length, (index) => AsciiAlphanumeric.tryFrom(value[index])!);

  static final _alphanumerics = RegExp(r'^[A-Za-z0-9]+$');
}
