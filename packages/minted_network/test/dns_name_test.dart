import 'package:checks/checks.dart';
import 'package:minted_network/minted_network.dart';

import 'support/bdd.dart';

void main() {
  feature('DnsName', () {
    // The names that made this type necessary: every one is refused by Hostname.
    scenarioOutline<({String input, String value})>(
      'DnsName.tryParse takes the underscored names Hostname refuses',
      examples: {
        'an ACME challenge': (
          input: '_acme-challenge.example.com',
          value: '_acme-challenge.example.com',
        ),
        'a DMARC policy': (input: '_dmarc.example.com', value: '_dmarc.example.com'),
        'an SRV service': (input: '_sip._tcp.example.com', value: '_sip._tcp.example.com'),
        'a DKIM selector': (
          input: 'selector1._domainkey.example.com',
          value: 'selector1._domainkey.example.com',
        ),
        'an ordinary name is still one': (input: 'www.example.com', value: 'www.example.com'),
      },
      outline: (example) {
        check(DnsName.tryParse(example.input)?.value).equals(example.value);
      },
    );

    // The three freedoms over Hostname, each its own rule that RFC 2181 drops.
    scenarioOutline<({String input, String? value})>(
      'the RFC 1123 rules that do not survive RFC 2181',
      examples: {
        'a hyphen may open a label': (input: '-bad.example.com', value: '-bad.example.com'),
        'and close one': (input: 'bad-.example.com', value: 'bad-.example.com'),
        'an all-numeric last label, which RFC 1123 calls an address': (
          input: '192.168.1.1',
          value: '192.168.1.1',
        ),
        'an underscore mid-label, which RFC 8552 never forbids': (
          input: 'a_b.example.com',
          value: 'a_b.example.com',
        ),
      },
      outline: (example) {
        check(DnsName.tryParse(example.input)?.value).equals(example.value);
      },
    );

    scenarioOutline<({String input, DnsNameFailure failure})>(
      'what it still refuses, and which rule it names',
      examples: {
        'non-ASCII wants punycode, not a character fix': (
          input: 'bücher.example',
          failure: const DnsNameNotAscii(),
        ),
        'a space is no DNS character': (
          input: 'a b.example.com',
          failure: const DnsNameInvalidCharacter(' '),
        ),
        'two dots met': (input: 'a..b.example.com', failure: const DnsNameLabelEmpty()),
        'a leading dot is the same fault': (
          input: '.example.com',
          failure: const DnsNameLabelEmpty(),
        ),
      },
      outline: (example) {
        check(DnsName.parse(example.input).reasonOrNull).equals(example.failure);
      },
    );

    scenario('the length limits are RFC 2181 §11, in presentation form', () {
      final longestLabel = 'a' * 63;
      final overlongLabel = 'a' * 64;
      check(DnsName.tryParse('$longestLabel.example.com')).isNotNull();
      check(DnsName.parse('$overlongLabel.example.com').reasonOrNull)
          .equals(const DnsNameLabelTooLong(64));

      // 255 characters of labels that are each short enough, so only the whole-name rule can fire.
      final overlongName = List.filled(64, 'abcd').join('.');
      check(overlongName.length).isGreaterThan(253);
      check(DnsName.parse(overlongName).reasonOrNull).equals(DnsNameTooLong(overlongName.length));
    });

    scenario('normalisation matches Hostname: trimmed, lower-cased, root dot folded', () {
      check(DnsName.tryParse('  _DMARC.Example.COM.  ')!.value).equals('_dmarc.example.com');
      check(DnsName.tryParse('_dmarc.example.com')).equals(DnsName.tryParse('_DMARC.EXAMPLE.COM.'));
      check(DnsName.tryParse('_dmarc.example.com')!.fqdn).equals('_dmarc.example.com.');
    });

    scenario('a bare root dot fails as an empty label rather than becoming empty', () {
      check(DnsName.parse('.').reasonOrNull).equals(const DnsNameLabelEmpty());
    });

    scenario('every Hostname widens to a DnsName, and only some narrow back', () {
      final host = Hostname.tryParse('www.example.com')!;
      check(DnsName.fromHostname(host).value).equals('www.example.com');
      check(DnsName.tryParse('www.example.com')!.tryToHostname()).equals(host);
      check(DnsName.tryParse('_dmarc.example.com')!.tryToHostname()).isNull();
      check(DnsName.tryParse('192.168.1.1')!.tryToHostname()).isNull();
      // Reverse DNS narrows fine: `arpa` is alphabetic, so the numeric-TLD rule never fires.
      check(DnsName.tryParse('4.3.2.1.in-addr.arpa')!.tryToHostname()).isNotNull();
    });

    scenarioOutline<({String input, bool underscored})>(
      'isUnderscored reports an RFC 8552 attribute leaf rather than gating on one',
      examples: {
        'a DMARC record': (input: '_dmarc.example.com', underscored: true),
        'an SRV name, underscored twice': (input: '_sip._tcp.example.com', underscored: true),
        'a DKIM selector, underscored in the middle': (
          input: 'selector1._domainkey.example.com',
          underscored: true,
        ),
        'an ordinary name': (input: 'www.example.com', underscored: false),
        'an underscore that does not open a label': (input: 'a_b.example.com', underscored: false),
      },
      outline: (example) {
        check(DnsName.tryParse(example.input)!.isUnderscored).equals(example.underscored);
      },
    );

    scenario('fromLabels is the inverse of labels, and reports parts that do not join', () {
      check(DnsName.fromLabels(['_dmarc', 'example', 'com']).getOrThrow().value)
          .equals('_dmarc.example.com');
      check(DnsName.tryParse('_sip._tcp.example.com')!.labels)
          .deepEquals(['_sip', '_tcp', 'example', 'com']);
      check(DnsName.fromLabels(['a b', 'example']).reasonOrNull).isA<DnsNameInvalidCharacter>();
    });

    scenario('the failure names the type, not its erased representation', () {
      check(DnsName.parse('a b.example.com').reasonOrNull?.typeName).equals('DnsName');
    });

    scenario('compareTo orders by the canonical form', () {
      final dmarc = DnsName.tryParse('_dmarc.example.com')!;
      final www = DnsName.tryParse('www.example.com')!;
      check(dmarc.compareTo(www)).isLessThan(0);
      check(dmarc.compareTo(DnsName.tryParse('_DMARC.example.com.')!)).equals(0);
    });
  });
}
