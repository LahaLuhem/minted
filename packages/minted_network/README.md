[![Pub Version](https://img.shields.io/pub/v/minted_network.svg)](https://pub.dev/packages/minted_network)
[![Pub Points](https://img.shields.io/pub/points/minted_network?logo=dart)](https://pub.dev/packages/minted_network/score)
[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/LahaLuhem/minted/blob/main/packages/minted_network/LICENSE)

# minted_network

Network addresses and names as well-modelled value types.

Part of the [minted](https://github.com/LahaLuhem/minted) family: pure-Dart value types built on
*parse, don't validate*, so the parser is the only door in and anything that came through it is
well-formed by construction. Once you hold an `IpAddress`, it *is* an address, in its RFC 5952
canonical spelling.

## Install

```sh
dart pub add minted_network
```

[`minted`](https://pub.dev/packages/minted) comes with it, holding the shared vocabulary
(`ParseOutcome`, `MintedFailure`, `Digit`, `Digits`, the `Uint` tower). Nothing here drags in
another domain's engine, and it's pure Dart, so unlike `InternetAddress` it works on the web too.

## What's in the box

| Type         | What it guarantees                                                                       | Standard                                                       |
|--------------|------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| `Hostname`   | the RFC 1123 grammar and both length limits; ASCII only, never an address                | [RFC 1123](https://www.rfc-editor.org/rfc/rfc1123#section-2.1) |
| `DnsName`    | the permissive counterpart: underscores and the rest of RFC 2181, so DKIM and SRV fit    | [RFC 2181](https://www.rfc-editor.org/rfc/rfc2181#section-11)  |
| `IpAddress`  | v4 or v6, canonicalised per RFC 5952; a leading zero refused, not read as octal          | [RFC 4291](https://www.rfc-editor.org/rfc/rfc4291)             |
| `Cidr`       | a network block: host bits must be clear, and `contains` masks rather than matching text | [RFC 4632](https://www.rfc-editor.org/rfc/rfc4632)             |
| `MacAddress` | 48 or 64 bits, four notations folded to one; the I/G and U/L bits read back              | [IEEE Std 802](https://en.wikipedia.org/wiki/MAC_address)      |
| `Port`       | the 0-65535 bound; the RFC 6335 band read back rather than gated on                      | [RFC 6335](https://www.rfc-editor.org/rfc/rfc6335)             |

`Hostname` enforces what `Uri` waves through: `-bad.com`, `a..b.com` and a 64-character label all
pass `Uri` without complaint. `DnsName` is the permissive counterpart rather than a relaxed
`Hostname`, so widening (`fromHostname`) always works and narrowing (`tryToHostname`) is a parse.

## A quick taste

```dart
// IpAddress: four spellings of one v6 address are four different map keys as Strings.
final address = IpAddress.tryParse('2001:0DB8:0:0:0:0:0:1')!;
address.value;    // '2001:db8::1'   (leading zeros gone, longest zero run compressed)
address.version;  // IpVersion.v6
IpAddress.tryParse('10.0.0.1')!.isPrivate;   // true   (RFC 1918; fc00::/7 for v6)

// a leading zero is refused rather than read, because inet_aton calls 010 octal and most
// parsers call it ten: accept it and one component can filter what another connects to.
IpAddress.parse('192.168.010.1').reasonOrNull?.message;
// '"010" has a leading zero, which is ambiguous between decimal and octal'

// Cidr holds an IpAddress and a prefix length rather than text, so contains() masks bits:
final block = Cidr.tryParse('10.0.0.0/8')!;
block.lastAddress.value;  // '10.255.255.255'
block.contains(IpAddress.tryParse('10.1.2.3')!);    // true
block.contains(IpAddress.tryParse('100.0.0.1')!);   // false, where a text prefix match says true

// host bits set is refused rather than silently masked, and the failure offers what you meant:
Cidr.parse('192.168.1.5/24').reasonOrNull?.message;
// 'has host bits set below the prefix; the network is "192.168.1.0/24"'

// Hostname: case and a trailing root dot normalise away, so one name has exactly one value:
final host = Hostname.tryParse('WWW.Example.COM.')!;
host.value;   // 'www.example.com'
host.fqdn;    // 'www.example.com.'   (rebuilds the trailing dot, which names the root)
Hostname.tryParse('192.168.1.1');    // null: that's an address, not a hostname
Hostname.tryParse('_sip.example.com');   // null: an underscore makes it a DNS name

// DnsName: the names DKIM, DMARC, ACME and SRV actually use:
final dmarc = DnsName.tryParse('_DMARC.Example.COM.')!;
dmarc.isUnderscored;         // true: an RFC 8552 attribute leaf, reported rather than gated on
DnsName.fromHostname(host);  // total, where dmarc.tryToHostname() is null

// MacAddress: four notations spell one address, and both widths keep theirs:
final mac = MacAddress.tryParse('00-00-5E-00-53-00')!;
mac.value;                    // '00:00:5e:00:53:00'   (canonical)
mac.isLocallyAdministered;    // false   (the U/L bit)
MacAddress.tryParse('0000.5e00.5300') == mac;   // true: Cisco's dot-quad is the same address

// Port: exactly a Uint16's range, so that type owns the bound. The RFC 6335 band reads back:
final port = Port.tryFrom(8080)!;
port.range;                   // PortRange.user
Port.tryFrom(0)!.isWildcard;  // true: bind(0) asks the OS for a free port
Port.tryFrom(65536);          // null, one past the 16-bit ceiling
```

The runnable version is the
[example](https://github.com/LahaLuhem/minted/blob/main/packages/minted_network/example/minted_network_example.dart).

## One shape, every type

- `Type.tryParse(input)` hands back the value, or `null` when the input isn't valid
- `Type.parse(input)` hands back a `ParseOutcome`: the value, or a typed failure
  (`IpAddressFailure`, `CidrFailure`, `HostnameFailure`, `DnsNameFailure`, `MacAddressFailure`) you
  can `switch` on, or read as a form-field message via `.reasonOrNull`. No door throws
- value equality, a canonical form to read back (`.value`, `.asString` on a `Cidr`), and an assembly
  factory (`from`, `fromOctets`, `fromLabels`) for parts you already hold
- `Port` is a constraint on a number rather than a parsed text form, so it takes `tryFrom(int)` and
  carries no failure vocabulary: with one invariant, `null` says everything a failure could

The [`minted` README](https://pub.dev/packages/minted) is the family guide: the whole catalogue,
handling failures, and the one caveat (never cast into a minted type).
