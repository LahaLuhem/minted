// substring splits at the ASCII '@' (a code-unit index), never inside a grapheme.
// ignore_for_file: avoid-substring

import 'package:email_validator/email_validator.dart';

import '../shared/minted_format_exception.dart';
import '../shared/parse_outcome.dart';
import 'failures/email_failure.dart';

/// An email address, validated against the RFC 5322 grammar (via
/// `email_validator`). Standard:
/// [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322).
///
/// Normalisation on parse: trimmed, domain lower-cased, local-part case
/// preserved (RFC 5321 leaves local-part case to the receiving host). So
/// `a@Example.com == a@example.com` but `A@x.com != a@x.com`.
extension type const Email._(String value) {
  /// Builds an [Email] from its [localPart] and [domain], throwing
  /// [MintedFormatException] if they don't form a valid address. For assembling
  /// from a known-valid source.
  static Email fromComponents({required String localPart, required String domain}) {
    final source = '$localPart@$domain';

    return parse(
      source,
    ).fold((reason) => throw MintedFormatException.from(reason, source), (email) => email);
  }

  /// As [fromComponents], but takes the domain as its dot-separated labels
  /// (`['example', 'com']`), joined with `.`.
  static Email fromDomainLabels({required String localPart, required List<String> domainLabels}) =>
      fromComponents(localPart: localPart, domain: domainLabels.join('.'));

  /// Parses [input] as an email address, or returns `null` when it is not well-formed.
  /// See the type docs for the normalisation applied.
  static Email? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an email address, reporting [EmailFailure] when it is not
  /// well-formed. See the type docs for the normalisation applied.
  static ParseOutcome<EmailFailure, Email> parse(String input) {
    final trimmed = input.trim();
    if (!EmailValidator.validate(trimmed)) return const ParseFailure(.malformed);

    final atSign = trimmed.lastIndexOf('@');

    return ParseSuccess(
      ._(
        '${trimmed.substring(0, atSign)}@'
        '${trimmed.substring(atSign + 1).toLowerCase()}',
      ),
    );
  }

  /// The local-part, before the last `@` (the mailbox name, often a username).
  /// Case is preserved from the input.
  String get localPart => value.substring(0, value.lastIndexOf('@'));

  /// The domain, after the last `@`. Always lower-case.
  String get domain => value.substring(value.lastIndexOf('@') + 1);

  /// A `mailto:` URI addressing this email.
  Uri get mailtoUri => Uri(scheme: 'mailto', path: value);
}
