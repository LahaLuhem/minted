// substring splits at the ASCII '@' (a code-unit index), never inside a grapheme.
// ignore_for_file: avoid-substring

import 'package:email_validator/email_validator.dart';
import 'package:minted/minted.dart';
import 'package:minted_network/minted_network.dart';

import 'failures/email_failure.dart';

/// An email address, checked against the RFC 5322 grammar by `email_validator`.
/// Standard: [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322).
///
/// Parsing trims and lower-cases the domain, keeping the local-part's case, which RFC 5321 leaves to
/// the receiving host. So `a@Example.com == a@example.com` but `A@x.com != a@x.com`.
///
/// The named constants pair an RFC 2142 mailbox with `example.com`, which RFC 2606 §3 reserves for
/// documentation, so none of them addresses a real inbox.
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

  /// `postmaster@example.com`. The one mailbox every SMTP server must accept. RFC 5321 §4.5.1.
  static const postmaster = Email._('postmaster@example.com');

  /// `hostmaster@example.com`, for DNS. RFC 2142 §7 asks a zone to name it in its SOA record.
  static const hostmaster = Email._('hostmaster@example.com');

  /// `usenet@example.com`, for NNTP news administration.
  static const usenet = Email._('usenet@example.com');

  /// `news@example.com`, the synonym for [usenet].
  static const news = Email._('news@example.com');

  /// `webmaster@example.com`, for the HTTP service.
  static const webmaster = Email._('webmaster@example.com');

  /// `www@example.com`, the synonym for [webmaster].
  static const www = Email._('www@example.com');

  /// `uucp@example.com`, for UUCP links.
  static const uucp = Email._('uucp@example.com');

  /// `ftp@example.com`, for the FTP archive.
  static const ftp = Email._('ftp@example.com');

  //===================================== NETWORK OPERATIONS =====================================//
  // RFC 2142 §4: recourse for anyone having trouble with the organisation's internet service.

  /// `abuse@example.com`, for reports of inappropriate public behaviour.
  static const abuse = Email._('abuse@example.com');

  /// `noc@example.com`, for the network infrastructure itself.
  static const noc = Email._('noc@example.com');

  /// `security@example.com`, for security bulletins and queries.
  static const security = Email._('security@example.com');

  //========================================== BUSINESS ==========================================//
  // RFC 2142 §3: the line-of-business mailboxes.

  /// `info@example.com`, for packaged information about the organisation and what it sells.
  static const info = Email._('info@example.com');

  /// `marketing@example.com`, for product marketing and communications.
  static const marketing = Email._('marketing@example.com');

  /// `sales@example.com`, for purchase information.
  static const sales = Email._('sales@example.com');

  /// `support@example.com`, for problems with the product or service.
  static const support = Email._('support@example.com');

  //======================================== CONVENTIONAL ========================================//
  // Habits, not standards. RFC 2142 names none of these, so treat a match as a hint rather than proof
  // of what is behind the mailbox.

  /// `mailer-daemon@example.com`, the bounce sender. RFC 3834 §2 says not to auto-reply to it.
  static const mailerDaemon = Email._('mailer-daemon@example.com');

  /// `no-reply@example.com`, the unattended sender. The unhyphenated `noreply@` is as common.
  static const noReply = Email._('no-reply@example.com');

  /// `admin@example.com`. RFC 2142's nearest equivalents are [hostmaster] and [noc].
  static const admin = Email._('admin@example.com');

  /// `root@example.com`, the Unix superuser that collects a host's system mail.
  static const root = Email._('root@example.com');
}
