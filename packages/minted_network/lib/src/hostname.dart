// A validated hostname is ASCII letters, digits, hyphens and dots, so slicing by index is safe.
// ignore_for_file: avoid-substring

import 'package:collection/collection.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';

import 'failures/hostname_failure.dart';
import 'standards/dns_names.dart';

part 'constants/hostname_constants.dart';
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
/// Named values: [HostnameConstants].
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
}
