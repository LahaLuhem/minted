// substring splits at the ASCII '@' (a code-unit index), never inside a grapheme.
// ignore_for_file: avoid-substring

import 'package:email_validator/email_validator.dart';
import 'package:minted/minted.dart';
import 'package:minted_network/minted_network.dart';

import 'failures/email_failure.dart';

part 'constants/email_constants.dart';

/// An email address, checked against the RFC 5322 grammar by `email_validator`.
/// Standard: [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322).
///
/// Parsing trims and lower-cases the domain, keeping the local-part's case, which RFC 5321 leaves to
/// the receiving host. So `a@Example.com == a@example.com` but `A@x.com != a@x.com`.
///
/// The named constants pair an RFC 2142 mailbox with `example.com`, which RFC 2606 §3 reserves for
/// documentation, so none of them addresses a real inbox.
///
/// Named values: [EmailConstants].
///
/// {@example /example/minted_contact_example.dart#email}
extension type const Email._(String value) {
  /// Builds an [Email] from its [localPart] and [domain], reporting [EmailFailure] when they don't form
  /// a valid address.
  static ParseOutcome<EmailFailure, Email> fromComponents({
    required String localPart,
    required String domain,
  }) => parse('$localPart@$domain');

  /// Parses [input], or `null` if it isn't a well-formed address.
  static Email? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting [EmailFailure] when it isn't a well-formed address.
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

  /// The local-part, before the last `@`: the mailbox name, often a username. Case is kept.
  String get localPart => value.substring(0, value.lastIndexOf('@'));

  /// The domain, after the last `@`. Always lower-case, but not always a [Hostname].
  String get domain => value.substring(value.lastIndexOf('@') + 1);

  /// The [domain] as a [Hostname], reporting the [HostnameFailure] when it isn't one. An address literal
  /// (`jane@[192.0.2.1]`) and an internationalised domain are valid addresses, not hostnames.
  ParseOutcome<HostnameFailure, Hostname> domainAsHostname() => Hostname.parse(domain);

  /// A `mailto:` URI addressing this email.
  Uri get mailtoUri => Uri(scheme: 'mailto', path: value);

  //====================================== SERVICE SUPPORT =======================================//
  // RFC 2142 §5: one mailbox per major protocol.
}
