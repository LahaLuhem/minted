// substring splits at the ASCII '@' (a code-unit index), never inside a grapheme.
// ignore_for_file: avoid-substring

import 'package:email_validator/email_validator.dart';

import 'shared/minted_format_exception.dart';

/// An email address, validated against the RFC 5322 grammar (via
/// `email_validator`). Standard:
/// [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322).
///
/// Normalisation on parse: trimmed, domain lower-cased, local-part case
/// preserved (RFC 5321 leaves local-part case to the receiving host). So
/// `a@Example.com == a@example.com` but `A@x.com != a@x.com`.
extension type const Email._(String value) {
  /// Parses [input] as an email address, or returns `null` when it is not well-formed.
  /// See the type docs for the normalisation applied.
  static Email? tryParse(String input) {
    final trimmed = input.trim();
    if (!EmailValidator.validate(trimmed)) return null;

    final atSign = trimmed.lastIndexOf('@');
    final normalised =
        '${trimmed.substring(0, atSign)}@'
        '${trimmed.substring(atSign + 1).toLowerCase()}';

    return Email._(normalised);
  }

  /// Parses [input] as an email address, throwing [MintedFormatException] when
  /// it is not well-formed.
  static Email parse(String input) =>
      tryParse(input) ??
      (throw MintedFormatException.of<Email>(input, 'not a well-formed email address'));

  /// The local-part, before the last `@`. Case is preserved from the input.
  String get localPart => value.substring(0, value.lastIndexOf('@'));

  /// The domain, after the last `@`. Always lower-case.
  String get domain => value.substring(value.lastIndexOf('@') + 1);

  /// A `mailto:` URI addressing this email.
  Uri get mailtoUri => Uri(scheme: 'mailto', path: value);
}
