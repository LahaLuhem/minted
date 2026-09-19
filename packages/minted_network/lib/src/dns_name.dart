import 'package:collection/collection.dart';
import 'package:minted/minted.dart';

import 'failures/dns_name_failure.dart';
import 'hostname.dart';
import 'standards/dns_names.dart';

part 'helpers/dns_name_helpers.dart';

/// A DNS name: the permissive counterpart to [Hostname], e.g. `_dmarc.example.com`.
/// Standards: [RFC 2181 §11](https://www.rfc-editor.org/rfc/rfc2181#section-11) for the syntax,
/// [RFC 8552](https://www.rfc-editor.org/rfc/rfc8552) for the underscored names that need it.
///
/// `_acme-challenge.example.com`, DKIM selectors and SRV names are what ACME, DMARC and service discovery
/// actually use, and [Hostname] refuses every one by design.
///
/// 3 things it takes that [Hostname] refuses: an underscore, a hyphen opening or closing a label,
/// and an all-numeric last label, so `192.168.1.1` is a name here. Still ASCII, for the reason [Hostname]
/// gives, and still inside RFC 2181's lengths. Why: `APPENDIX.md#dns-name-value-type`.
///
/// Parsing trims, lower-cases and drops one trailing root dot. [fqdn] puts the dot back.
///
/// {@example /example/minted_network_example.dart#dnsname}
extension type const DnsName._(String value) {
  /// The [DnsName] spelling of [hostname]. Total, where the narrowing [tryToHostname] is a parse.
  // Already normalised and strictly inside this type's rules, so there is nothing left to check.
  static DnsName fromHostname(Hostname hostname) => ._(hostname.value);

  /// Builds a [DnsName] from its [labels], reporting the [DnsNameFailure] unless they join into a valid
  /// one. The inverse of [labels].
  static ParseOutcome<DnsNameFailure, DnsName> fromLabels(List<String> labels) =>
      parse(labels.join(labelSeparator));

  /// Parses [input], or `null` if it breaks a charset or length rule.
  static DnsName? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [DnsNameFailure] that says which rule it broke.
  static ParseOutcome<DnsNameFailure, DnsName> parse(String input) {
    final normalisedInput = rootStripped(input.trim().toLowerCase());
    final failure = _failureFor(normalisedInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalisedInput));
  }

  /// This name as a [Hostname], or `null` when it uses the freedom [Hostname] refuses. Partial where
  /// [fromHostname] is total, which is what makes these 2 types rather than one.
  Hostname? tryToHostname() => Hostname.tryParse(value);

  /// The dot-separated labels, most specific first: `['_dmarc', 'example', 'com']`.
  List<String> get labels => value.split(labelSeparator);

  /// The fully-qualified spelling, `_dmarc.example.com.`, whose trailing dot names the root.
  String get fqdn => '$value$labelSeparator';

  /// Whether some label opens with an underscore, RFC 8552's mark of a DKIM, DMARC, ACME or SRV attribute
  /// leaf.
  bool get isUnderscored => labels.any((label) => label.startsWith(_underscore));

  /// Orders 2 names lexicographically by their canonical form.
  int compareTo(DnsName other) => value.compareTo(other.value);
}
