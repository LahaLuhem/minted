import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Hostname', () {
    final maxLabel = 'a' * 63;

    // The canonical form doubles as the expected outcome; null means rejected. Vectors are the
    // RFC 1123 and RFC 3696 rules, one row per rule, plus the cases Uri lets through.
    scenarioOutline<({String input, String? canonical})>(
      'Hostname.tryParse accepts RFC 1123 names, normalises them, and rejects the rest',
      examples: {
        'a canonical hostname': (input: 'www.example.com', canonical: 'www.example.com'),
        'uppercase is lower-cased': (input: 'WWW.EXAMPLE.COM', canonical: 'www.example.com'),
        'a trailing root dot is dropped': (input: 'example.com.', canonical: 'example.com'),
        'surrounding whitespace is trimmed': (input: '  example.com  ', canonical: 'example.com'),
        'a single label needs no dot': (input: 'localhost', canonical: 'localhost'),
        'a leading digit is allowed, which RFC 952 forbade': (
          input: '3com.example',
          canonical: '3com.example',
        ),
        'a last label may hold digits, so long as it is not all of them': (
          input: 'server1',
          canonical: 'server1',
        ),
        'an interior hyphen is allowed': (input: 'my-host.example', canonical: 'my-host.example'),
        'an A-label passes as ordinary letters and hyphens': (
          input: 'xn--bcher-kva.example',
          canonical: 'xn--bcher-kva.example',
        ),
        'a 63-character label is the limit, not past it': (
          input: '$maxLabel.example',
          canonical: '$maxLabel.example',
        ),
        'a leading hyphen is rejected, though Uri accepts it': (
          input: '-bad.example',
          canonical: null,
        ),
        'a trailing hyphen is rejected, though Uri accepts it': (
          input: 'bad-.example',
          canonical: null,
        ),
        'an empty label is rejected, though Uri accepts it': (
          input: 'a..b.example',
          canonical: null,
        ),
        'an underscore is rejected as a DNS name': (input: '_sip.example.com', canonical: null),
        'a non-ASCII name is rejected rather than punycoded': (
          input: 'bücher.example',
          canonical: null,
        ),
        'a dotted quad is an address, not a hostname': (input: '192.168.1.1', canonical: null),
        'an all-numeric last label is rejected whatever precedes it': (
          input: 'example.123',
          canonical: null,
        ),
        'a 64-character label is rejected': (input: '${maxLabel}a.example', canonical: null),
        'a space is rejected': (input: 'exa mple.com', canonical: null),
        'an empty string is rejected': (input: '', canonical: null),
        'a bare root dot is rejected rather than emptied': (input: '.', canonical: null),
      },
      outline: (example) {
        check(Hostname.tryParse(example.input)?.value).equals(example.canonical);
      },
    );

    // One row per variant, plus both arms of the two whose message branches on its payload.
    scenarioOutline<({String input, HostnameFailure failure})>(
      'Hostname.parse attributes the failure',
      examples: {
        'non-ASCII is named as such, not as a bad character': (
          input: 'bücher.example',
          failure: const HostnameNotAscii(),
        ),
        'an underscore echoes the character': (
          input: '_sip.example.com',
          failure: const HostnameInvalidCharacters('_'),
        ),
        'a space echoes the character': (
          input: 'exa mple.com',
          failure: const HostnameInvalidCharacters(' '),
        ),
        'an empty label reports itself empty': (
          input: 'a..b.example',
          failure: const HostnameLabelMalformed(''),
        ),
        'a hyphen at a label edge echoes the label': (
          input: '-bad.example',
          failure: const HostnameLabelMalformed('-bad'),
        ),
        'a label past 63 reports its length': (
          input: '${maxLabel}a.example',
          failure: const HostnameLabelTooLong(64),
        ),
        'a dotted quad is an address': (input: '192.168.1.1', failure: const HostnameNumericTld()),
      },
      outline: (example) {
        check(Hostname.parse(example.input).reasonOrNull).equals(example.failure);
      },
    );

    scenario('the whole name is capped at 253 characters, not RFC 1035 wire format 255', () {
      // Four maximal labels and their dots make 255; trimming the last to 61 lands on the limit.
      final atLimit = [maxLabel, maxLabel, maxLabel, 'a' * 61].join('.');
      final pastLimit = [maxLabel, maxLabel, maxLabel, maxLabel].join('.');

      check(atLimit.length).equals(253);
      check(Hostname.tryParse(atLimit)?.value).equals(atLimit);
      check(Hostname.parse(pastLimit).reasonOrNull).equals(const HostnameTooLong(255));
    });

    scenario('equal hostnames are equal, whichever spelling they are built from', () {
      final canonical = Hostname.tryParse('www.example.com')!;

      check(Hostname.tryParse('WWW.Example.COM')!).equals(canonical);
      check(Hostname.tryParse('www.example.com.')!).equals(canonical);
      check(Hostname.tryParse('  WWW.EXAMPLE.COM.  ')!).equals(canonical);
    });

    scenario('labels reads the name apart, most specific first', () {
      check(Hostname.tryParse('www.example.com')!.labels).deepEquals(['www', 'example', 'com']);
      check(Hostname.tryParse('localhost')!.labels).deepEquals(['localhost']);
    });

    scenario('fqdn rebuilds the trailing-dot spelling parse dropped', () {
      check(Hostname.tryParse('www.example.com.')!.fqdn).equals('www.example.com.');
      check(Hostname.tryParse('localhost')!.fqdn).equals('localhost.');
    });

    scenario('fromLabels round-trips through labels and reports parts that do not form one', () {
      final hostname = Hostname.fromLabels(['www', 'example', 'com']).getOrThrow();

      check(hostname.value).equals('www.example.com');
      check(Hostname.fromLabels(hostname.labels).getOrThrow()).equals(hostname);
      check(Hostname.fromLabels(['bad-', 'example']).reasonOrNull).isA<HostnameLabelMalformed>();
      check(Hostname.fromLabels(['192', '168', '1', '1']).reasonOrNull).isA<HostnameNumericTld>();
    });

    scenario('the failure message names the remedy, not just the rule', () {
      check(Hostname.parse('_sip.example.com').reasonOrNull?.message)
          .equals('an underscore makes this a DNS name, not a hostname');
      check(Hostname.parse('bücher.example').reasonOrNull?.message)
          .equals('contains non-ASCII, so punycode it to an A-label first');
    });

    scenario('compareTo orders lexicographically by canonical form', () {
      final earlier = Hostname.tryParse('a.example')!;
      final later = Hostname.tryParse('b.example')!;

      check(earlier.compareTo(later)).isLessThan(0);
      check(later.compareTo(earlier)).isGreaterThan(0);
      // Comparator test
      // ignore: avoid-passing-self-as-argument
      check(earlier.compareTo(earlier)).equals(0);
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Hostname.parse('-bad.example'))
          .equals(const ParseFailure(HostnameLabelMalformed('-bad')));
      check(Hostname.parse('example.com').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Hostname.tryParse('-bad.example')).isNull();
      check(Hostname.tryParse('example.com')?.value).equals('example.com');
    });

    scenario('the failure names the type, not its erased representation', () {
      // Extension types erase to String at runtime, so a `<T>`-derived name would read "String".
      check(Hostname.parse('_x.example').reasonOrNull?.typeName).equals('Hostname');
      check(Hostname.fromLabels(['-bad']).reasonOrNull?.typeName).equals('Hostname');
    });
  });
}
