// A validated hostname is ASCII letters, digits, hyphens and dots, so slicing by index is safe.
// ignore_for_file: avoid-substring

import 'package:collection/collection.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';

import 'failures/hostname_failure.dart';
import 'standards/dns_names.dart';

part 'helpers/hostname_helpers.dart';

/// A hostname: the dot-separated name of a host on a network, e.g. `www.example.com`.
/// Standards: [RFC 1123 §2.1](https://www.rfc-editor.org/rfc/rfc1123#section-2.1) for the grammar,
/// [RFC 1035 §2.3.4](https://www.rfc-editor.org/rfc/rfc1035#section-2.3.4) for the size limits.
///
/// `Uri` waves through `-bad.com`, `a..b.com` and a 64-character label, so a broken host survives as
/// far as a failed DNS lookup. A [Hostname] doesn't.
///
/// 3 things it refuses on purpose. Non-ASCII, because punycode alone isn't IDNA, so `xn--bcher-kva.example`
/// parses and `bücher.example` doesn't. An underscore, which makes a name a DNS name rather than a hostname.
/// And a dotted quad, which RFC 1123 says a host name never is. Why: `APPENDIX.md#hostname-value-type`.
///
/// Parsing trims, lower-cases (RFC 1035 makes DNS comparison case-insensitive) and drops one trailing
/// root dot, so `EXAMPLE.com.` and `example.com` are one value. [fqdn] puts the dot back.
///
/// {@example /example/minted_network_example.dart#hostname}
extension type const Hostname._(String value) {
  /// Builds a [Hostname] from its [labels], reporting the [HostnameFailure] unless they join into a
  /// valid one. The inverse of [labels].
  static ParseOutcome<HostnameFailure, Hostname> fromLabels(List<String> labels) =>
      parse(labels.join(labelSeparator));

  /// Parses [input], or `null` if it breaks any RFC 1123 rule.
  static Hostname? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [HostnameFailure] that says which rule it broke.
  static ParseOutcome<HostnameFailure, Hostname> parse(String input) {
    final normalisedInput = rootStripped(input.trim().toLowerCase());
    final failure = _failureFor(normalisedInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalisedInput));
  }

  /// The dot-separated labels, most specific first: `['www', 'example', 'com']`.
  List<String> get labels => value.split(labelSeparator);

  /// The fully-qualified spelling, `www.example.com.`, whose trailing dot names the root. RFC 3696 calls
  /// the 2 equivalent, which is why parsing drops it.
  String get fqdn => '$value$labelSeparator';

  /// Orders 2 hostnames lexicographically by their canonical form.
  int compareTo(Hostname other) => value.compareTo(other.value);

  //===================================== RFC 2606 RESERVED ======================================//
  // Both of its sets, whole: 4 top-level names in §2 and 3 second-level ones in §3.

  /// The loopback name, which resolves without asking a nameserver.
  static const localhost = Hostname._('localhost');

  /// Reserved for testing, so it will never be delegated.
  static const test = Hostname._('test');

  /// Reserved to be obviously wrong, for a name that has to fail.
  static const invalid = Hostname._('invalid');

  /// Reserved for documentation and examples.
  static const example = Hostname._('example');

  /// `example.com`, reserved for documentation.
  static const exampleCom = Hostname._('example.com');

  /// `example.net`, reserved for documentation.
  static const exampleNet = Hostname._('example.net');

  /// `example.org`, reserved for documentation.
  static const exampleOrg = Hostname._('example.org');

  //======================================== SPECIAL-USE =========================================//

  /// Multicast DNS, so a name resolved by shouting on the local link. RFC 6762.
  static const local = Hostname._('local');

  /// Private-use TLD, reserved by ICANN in 2024 rather than by an RFC.
  static const internal = Hostname._('internal');

  //======================================== CONVENTIONAL ========================================//
  // Habits, not standards. Nothing reserves these, so treat a match as a hint, never as proof.

  /// The `/etc/hosts` loopback line most Linux distributions ship.
  static const localhostLocaldomain = Hostname._('localhost.localdomain');

  /// The bare suffix behind [localhostLocaldomain].
  static const localdomain = Hostname._('localdomain');

  /// What home routers hand out as the search domain.
  static const lan = Hostname._('lan');

  /// A home network. ICANN shelved `.home` as a new gTLD over exactly this collision risk.
  static const home = Hostname._('home');

  /// A company network. Shelved alongside [home], and for the same reason.
  static const corp = Hostname._('corp');
}
