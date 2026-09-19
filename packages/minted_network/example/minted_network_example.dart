// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted_network/minted_network.dart';

void main() {
  // Folds the 4 notations, so the spelling a device or a log happens to use stops mattering.
  // #region mac
  final mac = MacAddress.tryParse('00-00-5E-00-53-00')!;
  print(mac.value); // 00:00:5e:00:53:00  (canonical: colon-separated, lower-case)
  print(mac.ieee802); // 00-00-5E-00-53-00  (the IEEE hyphen form)
  print(mac.prefix24); // 00:00:5e  (the first three octets, deliberately not called an OUI)
  print(mac.isLocallyAdministered); // false  (the U/L bit, read back rather than gating the parse)
  print(MacAddress.tryParse('0000.5e00.5300') == mac); // true (Cisco dot-quad, same address)
  print(MacAddress.tryParse('0:0:5e:0:53:0')); // null (omitted leading zeros aren't a MAC address)
  // #endregion

  // Enforces what `Uri` waves through: RFC 1123's grammar and both length limits.
  // #region hostname
  final host = Hostname.tryParse('WWW.Example.COM.')!;
  print(host.value); // www.example.com
  print(host.labels); // [www, example, com]
  print(host.fqdn); // www.example.com.  (rebuilds the trailing dot, which names the root)
  print(Hostname.tryParse('bücher.example')); // null (punycode it yourself: we do not do IDNA)
  print(Hostname.tryParse('192.168.1.1')); // null (an address, not a hostname)
  print(
    Hostname.parse('_sip.example.com').reasonOrNull?.message,
  ); // an underscore makes this a DNS name, not a hostname
  // #endregion

  // The permissive counterpart. RFC 2181 drops the charset rule, which is how DKIM, DMARC, ACME and
  // SRV names get to exist.
  // #region dnsname
  final dmarc = DnsName.tryParse('_DMARC.Example.COM.')!;
  print(dmarc.value); // _dmarc.example.com  (same normalisation Hostname applies)
  print(dmarc.isUnderscored); // true (an RFC 8552 attribute leaf, reported not gated)
  print(DnsName.tryParse('-bad.example.com')?.value); // -bad.example.com, legal DNS if not a host
  print(dmarc.tryToHostname()); // null: narrowing is a parse, and this one fails it
  print(DnsName.fromHostname(host).value); // www.example.com, and widening never fails
  // #endregion

  // Canonicalises per RFC 5952, so the 4 spellings of one v6 address stop being 4 map keys. `InternetAddress`
  // can't do this job, being `dart:io` and so absent on the web.
  // #region ipaddress
  final address = IpAddress.tryParse('2001:0DB8:0:0:0:0:0:1')!;
  print(address.value); // 2001:db8::1  (leading zeros gone, longest zero run compressed)
  print(address.version); // IpVersion.v6
  print(IpAddress.tryParse('10.0.0.1')?.isPrivate); // true  (RFC 1918; fc00::/7 for v6)
  print(IpAddress.tryParse('0:0:0:0:0:ffff:c000:201')?.value); // ::ffff:192.0.2.1  (RFC 5952 §5)
  print(
    IpAddress.parse('192.168.010.1').reasonOrNull?.message,
  ); // "010" has a leading zero, which is ambiguous between decimal and octal
  // #endregion

  // Holds an `IpAddress` and a prefix length rather than text, so `contains` masks bits. Matching a
  // string prefix would call 100.0.0.1 part of 10.0.0.0/8.
  // #region cidr
  final block = Cidr.tryParse('10.0.0.0/8')!;
  print(block.asString); // 10.0.0.0/8
  print(block.lastAddress.value); // 10.255.255.255
  print(block.contains(IpAddress.tryParse('10.1.2.3')!)); // true
  print(block.contains(IpAddress.tryParse('100.0.0.1')!)); // false (a text prefix match says true)
  print(
    Cidr.parse('192.168.1.5/24').reasonOrNull?.message,
  ); // has host bits set below the prefix. The network is "192.168.1.0/24"
  // #endregion

  // Exactly a `Uint16`'s range, so that type owns the bound. The RFC 6335 band is read back.
  // #region port
  final port = Port.tryFrom(8080)!;
  print(port.value); // 8080
  print(port.range); // PortRange.user
  print(Port.tryFrom(443)!.range); // PortRange.system  (well-known)
  print(Port.tryFrom(0)!.isWildcard); // true  (bind(0) asks the OS for a free port)
  print(Port.tryFrom(65536)); // null (one past the 16-bit ceiling)
  // #endregion
}
