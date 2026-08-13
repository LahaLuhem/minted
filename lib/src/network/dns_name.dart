import 'package:collection/collection.dart';

import '../shared/outcomes/minted_format_exception.dart';
import '../shared/outcomes/parse_outcome.dart';
import '../shared/standards/dns_names.dart';
import 'failures/dns_name_failure.dart';
import 'hostname.dart';

/// A DNS name: the permissive counterpart to [Hostname], e.g. `_dmarc.example.com`.
/// Standards: [RFC 2181 §11](https://www.rfc-editor.org/rfc/rfc2181#section-11) for the syntax,
/// [RFC 8552](https://www.rfc-editor.org/rfc/rfc8552) for the underscored names that need it.
///
/// Parse, don't validate: `_acme-challenge.example.com`, DKIM selectors and SRV names are what
/// ACME, DMARC and service discovery actually use, and [Hostname] refuses every one by design. The
/// alternative is a bare `String` exactly where a type was supposed to help.
///
/// Wider than [Hostname] in three ways: an underscore is allowed, a label may open or close with a
/// hyphen, and the last label may be all digits, so `192.168.1.1` is a name here where RFC 1123
/// calls it an address. Still ASCII, for the reason [Hostname] gives, and still bounded by RFC
/// 2181's lengths. RFC 2181 permits any octet and leaves further limits to the application; this is
/// that limit.
/// Why: `APPENDIX.md#dns-name-value-type`.
///
/// Normalisation on parse: trimmed, lower-cased (RFC 1035 makes DNS comparison case-insensitive),
/// and one trailing root dot dropped. [fqdn] rebuilds the trailing-dot spelling.
///
/// {@example /example/minted_example.dart#dnsname}
extension type const DnsName._(String value) {
  /// The [DnsName] spelling of [hostname]. Total, because every hostname is a DNS name; the
  /// narrowing direction is [tryToHostname], which is a parse.
  // Already normalised and strictly inside this type's rules, so there is nothing left to check.
  static DnsName fromHostname(Hostname hostname) => ._(hostname.value);

  /// Builds a [DnsName] from its [labels] (`['_dmarc', 'example', 'com']`), throwing
  /// [MintedFormatException] unless they join into a valid one. The inverse of [labels].
  static DnsName fromLabels(List<String> labels) {
    final source = labels.join(labelSeparator);

    return parse(source)
        .fold((reason) => throw MintedFormatException.from(reason, source), (dnsName) => dnsName);
  }

  /// Parses [input] as a DNS name, or returns `null` when it breaks a charset or length rule.
  /// See the type docs for the normalisation applied.
  static DnsName? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a DNS name, reporting the [DnsNameFailure] that says which rule it broke.
  static ParseOutcome<DnsNameFailure, DnsName> parse(String input) {
    final normalisedInput = rootStripped(input.trim().toLowerCase());
    final failure = _failureFor(normalisedInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalisedInput));
  }

  /// This name as a [Hostname], or `null` when it uses the freedom [Hostname] refuses. Partial
  /// where [fromHostname] is total, which is what makes these two types rather than one.
  Hostname? tryToHostname() => Hostname.tryParse(value);

  /// The dot-separated labels, most specific first: `['_dmarc', 'example', 'com']`.
  List<String> get labels => value.split(labelSeparator);

  /// The fully-qualified spelling, `_dmarc.example.com.`, whose trailing dot names the root.
  String get fqdn => '$value$labelSeparator';

  /// Whether this is an underscored name in RFC 8552's sense: some label opens with an underscore,
  /// which is what marks a DKIM, DMARC, ACME or SRV attribute leaf.
  bool get isUnderscored => labels.any((label) => label.startsWith(_underscore));

  /// Orders two names lexicographically by their canonical form. Extension types cannot implement
  /// `Comparable<DnsName>`, so this is a plain method, not the [Comparable] interface.
  int compareTo(DnsName other) => value.compareTo(other.value);

  // Ordered so each check can assume the ones before it passed.
  static DnsNameFailure? _failureFor(String normalisedInput) {
    final offendingCharacter = _offendingCharacter(normalisedInput);
    if (offendingCharacter != null) {
      return isNonAscii(offendingCharacter)
          ? const DnsNameNotAscii()
          : DnsNameInvalidCharacters(offendingCharacter);
    }
    if (normalisedInput.length > maxNameLength) return DnsNameTooLong(normalisedInput.length);

    final labels = normalisedInput.split(labelSeparator);
    if (labels.any((label) => label.isEmpty)) return const DnsNameLabelEmpty();

    final overlongLabel = labels.firstWhereOrNull((label) => label.length > maxLabelLength);

    return overlongLabel != null ? DnsNameLabelTooLong(overlongLabel.length) : null;
  }

  // The first character that is neither a label character nor the separator, or null when all pass.
  static String? _offendingCharacter(String normalisedInput) =>
      normalisedInput.split('').firstWhereOrNull((character) => !_allowed.hasMatch(character));

  static final _allowed = RegExp('[0-9a-z._-]');

  static const _underscore = '_';
}
