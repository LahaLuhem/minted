// substring splits at the ASCII '@' (a code-unit index), never inside a grapheme.
// ignore_for_file: avoid-substring

import 'package:email_validator/email_validator.dart';
import 'package:minted/minted.dart';
import 'package:minted_network/minted_network.dart';

import 'failures/email_failure.dart';

/// An email address, validated against the RFC 5322 grammar (via
/// `email_validator`). Standard:
/// [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322).
///
/// Normalisation on parse: trimmed, domain lower-cased, local-part case
/// preserved (RFC 5321 leaves local-part case to the receiving host). So
/// `a@Example.com == a@example.com` but `A@x.com != a@x.com`.
///
/// {@example /example/minted_contact_example.dart#email}
extension type const Email._(String value) {
  /// Builds an [Email] from its [localPart] and [domain], reporting [EmailFailure] when they don't
  /// form a valid address.
  static ParseOutcome<EmailFailure, Email> fromComponents({
    required String localPart,
    required String domain,
  }) => parse('$localPart@$domain');

  /// Parses [input] as an email address, or returns `null` when it is not well-formed.
  /// See the type docs for the normalisation applied.
  static Email? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an email address, reporting [EmailFailure] when it is not
  /// well-formed. See the type docs for the normalisation applied.
  static ParseOutcome<EmailFailure, Email> parse(String input) {
    final trimmedInput = input.trim();
    if (!EmailValidator.validate(trimmedInput)) return const ParseFailure(.malformed);

    final atSignIndex = trimmedInput.lastIndexOf('@');

    return ParseSuccess(
      ._(
        '${trimmedInput.substring(0, atSignIndex)}@'
        '${trimmedInput.substring(atSignIndex + 1).toLowerCase()}',
      ),
    );
  }

  /// The local-part, before the last `@` (the mailbox name, often a username).
  /// Case is preserved from the input.
  String get localPart => value.substring(0, value.lastIndexOf('@'));

  /// The domain, after the last `@`. Always lower-case. Not always a [Hostname]: see
  /// [domainAsHostname].
  String get domain => value.substring(value.lastIndexOf('@') + 1);

  /// The [domain] as a [Hostname], reporting the [HostnameFailure] when it is not one: an address
  /// literal (`jane@[192.0.2.1]`) and an internationalised domain are valid addresses but not
  /// hostnames.
  ParseOutcome<HostnameFailure, Hostname> domainAsHostname() => Hostname.parse(domain);

  /// A `mailto:` URI addressing this email.
  Uri get mailtoUri => Uri(scheme: 'mailto', path: value);
}
