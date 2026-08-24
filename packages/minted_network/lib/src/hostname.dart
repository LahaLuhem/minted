// A validated hostname is ASCII letters, digits, hyphens and dots, so slicing by index is safe.
// ignore_for_file: avoid-substring

import 'package:collection/collection.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';

import 'failures/hostname_failure.dart';
import 'standards/dns_names.dart';

/// A hostname: the dot-separated name of a host on a network, e.g. `www.example.com`.
/// Standards: [RFC 1123 §2.1](https://www.rfc-editor.org/rfc/rfc1123#section-2.1) for the grammar,
/// [RFC 1035 §2.3.4](https://www.rfc-editor.org/rfc/rfc1035#section-2.3.4) for the size limits.
///
/// Parse, don't validate: `Uri` accepts `-bad.com`, `a..b.com` and a 64-character label without
/// complaint, so a malformed host survives as far as a failed DNS lookup. A [Hostname] does not.
///
/// Three things it refuses on purpose. Non-ASCII, because punycode alone is not IDNA, so
/// `xn--bcher-kva.example` parses and `bücher.example` does not. An underscore, which makes a name
/// a DNS name rather than a hostname. And a dotted quad, which RFC 1123 says a host name never is.
/// Why: `APPENDIX.md#hostname-value-type`.
///
/// Normalisation on parse: trimmed, lower-cased (RFC 1035 makes DNS comparison case-insensitive),
/// and one trailing root dot dropped, so `EXAMPLE.com.` and `example.com` are one value. [fqdn]
/// rebuilds the trailing-dot spelling.
///
/// {@example /example/minted_network_example.dart#hostname}
extension type const Hostname._(String value) {
  /// Builds a [Hostname] from its [labels] (`['www', 'example', 'com']`), reporting the
  /// [HostnameFailure] unless they join into a valid one. The inverse of [labels].
  static ParseOutcome<HostnameFailure, Hostname> fromLabels(List<String> labels) =>
      parse(labels.join(labelSeparator));

  /// Parses [input] as a hostname, or returns `null` when it breaks any RFC 1123 rule.
  /// See the type docs for the normalisation applied.
  static Hostname? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a hostname, reporting the [HostnameFailure] that says which rule it broke.
  static ParseOutcome<HostnameFailure, Hostname> parse(String input) {
    final normalisedInput = rootStripped(input.trim().toLowerCase());
    final failure = _failureFor(normalisedInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalisedInput));
  }

  /// The dot-separated labels, most specific first: `['www', 'example', 'com']`.
  List<String> get labels => value.split(labelSeparator);

  /// The fully-qualified spelling, `www.example.com.`, whose trailing dot names the root.
  /// RFC 3696 calls the two equivalent, which is why parse drops it.
  String get fqdn => '$value$labelSeparator';

  /// Orders two hostnames lexicographically by their canonical form. Extension types cannot
  /// implement `Comparable<Hostname>`, so this is a plain method, not the [Comparable] interface.
  int compareTo(Hostname other) => value.compareTo(other.value);

  // Ordered so each check can assume the ones before it passed.
  static HostnameFailure? _failureFor(String normalisedInput) {
    final offendingCharacter = _offendingCharacter(normalisedInput);
    if (offendingCharacter != null) {
      return isNonAscii(offendingCharacter)
          ? const HostnameNotAscii()
          : HostnameInvalidCharacter(offendingCharacter);
    }
    if (normalisedInput.length > maxNameLength) return HostnameTooLong(normalisedInput.length);

    final labels = normalisedInput.split(labelSeparator);
    final malformedLabel = labels.firstWhereOrNull(_isMalformed);
    if (malformedLabel != null) return HostnameLabelMalformed(malformedLabel);

    final overlongLabel = labels.firstWhereOrNull((label) => label.length > maxLabelLength);
    if (overlongLabel != null) return HostnameLabelTooLong(overlongLabel.length);

    return !digitsOnly.hasMatch(labels.last) ? null : const HostnameNumericTld();
  }

  // The first character that is neither a label character nor the separator, or null when all pass.
  static String? _offendingCharacter(String normalisedInput) =>
      normalisedInput.split('').firstWhereOrNull((character) => !_allowed.hasMatch(character));

  static bool _isMalformed(String label) =>
      label.isEmpty || label.startsWith(hyphen) || label.endsWith(hyphen);

  static final _allowed = RegExp('[0-9a-z.-]');
}
