# APPENDIX — `minted_network`

Design rationale for the types this package ships: the "why" behind decisions the code and its
dartdoc alone don't explain. Family-wide rationale (parse-don't-validate, the failure model,
packaging, the shared rules every type leans on) lives in the [workspace APPENDIX][appendix-md];
code style in [CODESTYLE.md][codestyle-md]. Each heading carries an explicit `<a id="…">` anchor;
link by anchor, and keep anchors stable across renames.

<!-- TOC start -->

- [MacAddress: two widths, four notations, and no registry](#mac-address-value-type)
- [Hostname: strict on purpose, in three directions](#hostname-value-type)
- [DnsName: permissive, but not infinitely so](#dns-name-value-type)
- [IpAddress: a wrapped engine, but not a wrapped grammar](#ip-address-value-type)
- [Cidr: a block that masks, not a string that starts with](#cidr-value-type)
- [Port: a domain that borrows a width](#port-value-type)

<!-- TOC end -->

---

<a id="mac-address-value-type"></a>
## MacAddress: two widths, four notations, and no registry

**The type is not called `Eui48`, because an EUI-48 is a narrower thing than a 48-bit MAC address.**
The IEEE Registration Authority's [guidelines for EUI, OUI and
CID](https://standards.ieee.org/wp-content/uploads/import/documents/tutorials/eui.pdf) retire the
term `MAC-48` and warn that `EUI-48` is *not* its replacement, because an EUI-48 "only refers to
individual, universally/globally unique network addresses". A broadcast, multicast or
locally-administered address is a MAC address and is not an EUI-48, so a type named for the narrower
term would refuse most of what its name promises. RFC 9542 §1.1 says the same. This is the [`Day`
test][date-value-type] again, applied to a name rather than a field.

**Both widths are kept, and neither is converted, because the conversion is deprecated in its
entirety.** The same RA document states that "mapping an EUI-48 to an EUI-64 is deprecated", for
both the `FF-FE` and `FF-FF` fillers, since an address assigned under MA-M or MA-S can collide once
widened. It does not reverse either: a genuine EUI-64 may legitimately carry `FF-FE` in octets 3-4,
so no `toEui48()` could tell an encoded address from a native one. That kills the tempting analogy
with [`Isbn`][isbn-value-type], whose 978 fold *is* a bijection, and with [`Gtin`][gtin-value-type],
where padding is lossless. Accepting both widths costs nothing and touches none of it, and an
802.15.4 or Thread address is a MAC address, so a type named `MacAddress` that refused it would
under-deliver. The cost is that `octets.length` is not a constant, which is why this was settled
before the type shipped rather than retrofitted: adding the second width later would be a soft break
for anyone who assumed six.

**The canonical form is colon-separated lower-case, which knowingly collides with IEEE Std 802
Clause 8.1.** That clause reads a *colon* separator as the bit-reversed representation, a different
value: IEEE's own worked example has `AC-DE-48-12-7B-80` in hexadecimal representation equal to
`35:7B:12:48:DE:01` bit-reversed. Taking the colon form as canonical anyway is a considered break,
not an oversight. RFC 9911 §3 calls lower-case colon the canonical representation, `ether_ntoa` and
essentially every tool emit it, [`Uuid`][uuid-value-type] already lower-cases its hex, and IEEE
802.1's own YANG work has recorded that near-universal practice "seems to technically violate
subclause 8.1" and asked for the bit-reversal reading to move to an informative annex as historic.
`ieee802` renders the standard's hyphenated upper-case form for anyone who needs it.

**`prefix24`, not `oui`, because the assignment boundary is not in the address.** The IEEE issues
three block sizes (RFC 9542 §2.1, Table 1): MA-L at 24 bits, MA-M at 28, MA-S at 36. The RA states
that "the MA-M does not include assignment of an OUI", and that an OUI-36 assignee "shall not
truncate the OUI-36 to use as an OUI", since the RA hands the same base prefix to many
organisations. So for an MA-M or MA-S address the first 24 bits identify nobody, and telling the
cases apart needs a lookup in three registries. RFC 9542 §2.1.2 adds a second limit: with the local
bit set, "the holder of an OUI has no special authority" over those bits at all. A getter named
`oui` would therefore promise what the data cannot support, the same defect
[`Isni`][isni-value-type] avoids by reporting the ORCID block rather than gating on it. Vendor
lookup is out for the usual reason on top of that: the registry is a 4 MB CSV, i.e. [a
clock][registry-data-ships-a-clock].

**The bits need no reversal, though they look as if they should.** I/G and U/L are defined by
transmission order, which is least-significant-bit-first on Ethernet, while hex is written
most-significant-first. They coincide, because "the first bit transmitted, of each octet, on the LAN
medium is the least significant bit of that octet", so a plain mask on the octet's integer value is
correct. The second hex digit alone therefore fixes both bits, which is what the type's test table
walks end to end.

**Deliberately not modelled**, each because it would state more than the address does: EUI-48 to
EUI-64 conversion in either direction; RFC 4291's "Modified EUI-64" (an IETF construct, itself
superseded by RFC 7217 and RFC 8064); IEEE 802c's SLAP quadrants, since RFC 9542 §2.1.1 notes the
SLAP is optional with "no automated way to determine" whether a network runs it, so an enum would
dress a nominal bit pattern as a fact about the wire; vendor lookup; the bit-reversed colon
notation; and an `unspecified` constant for `00:00:00:00:00:00`, which is a real Xerox MA-L address
whose "unspecified" meaning is a per-protocol convention rather than an IEEE reservation.

**Input is strict where the wild is loose.** glibc's `ether_ntoa` omits leading zeros, so
`1:2:3:4:5:6` is real output somewhere, and it is rejected here: it matches no standard's grammar,
and a parser that guessed would be hand-writing octets the input did not contain. The four accepted
notations each get their own anchored alternative in one regex, which is what refuses a spelling
that mixes two separators.

---

<a id="hostname-value-type"></a>
## Hostname: strict on purpose, in three directions

**ASCII only, because punycode is not IDNA.** The tempting shortcut is to depend on a punycode
package and fold `bücher.example` to `xn--bcher-kva.example` on parse. RFC 5890 §2.3.2.1 does not
allow it: an A-label needs punycode validity *plus* IDNA2008 validity, NFC, and the Bidi and Context
rules, and "if and only if a string meeting the above requirements can be decoded into a U-label is
it an A-label". The RFC has a name for what you get otherwise, a **fake A-label**. pub.dev carries
punycode implementations and no IDNA one, so encoding here would advertise a conformance nothing in
the dependency tree can back. Refusing says the true thing, and an already-encoded A-label parses
for free, being ordinary letters, digits and hyphens. Same call as
[`prefix24`](#mac-address-value-type) declining the name `oui`.

**A hostname, not a DNS name.** RFC 1123 is LDH: letters, digits, hyphen. RFC 2181 later liberalised
*DNS names* to carry essentially any octet, which is why `_acme-challenge.example.com`, DKIM
selectors and SRV records exist and work. Those are not hostnames, and a type that accepted them
could not promise its value is usable wherever a host is expected. So the underscore is refused, and
because that refusal will surprise people, the failure says `an underscore makes this a DNS name,
not a hostname` rather than lumping it in with a stray character. The permissive counterpart shipped
as [`DnsName`](#dns-name-value-type), a second type rather than a flag on this one.

**Never an address.** RFC 1123 §2.1 settles what looks like an open question: "a valid host name can
never have the dotted-decimal form #.#.#.#, since at least the highest-level component label will be
alphabetic". The dotted-quad advice in that same section is about what a *resolver* should accept
from a user, not about what a host name is. Enforcing it needs care, though: read literally, "the
highest-level label is alphabetic" would refuse `server1`. The rule that actually holds is RFC
3696's, that a top-level label is never *all*-numeric, which refuses `192.168.1.1` and admits
`server1`.

**253, not 255.** RFC 1035 §2.3.4 caps a name at 255 octets, but that is the wire form, which spends
a length octet per label and a null for the root. Presentation form is therefore two shorter, and
253 is what a string can hold. Both numbers are correct about different things, which is why the
type names the limit it enforces.

**The trailing dot folds rather than surviving.** RFC 3696 §2 calls `a.b.c` and `a.b.c.` equivalent
and requires applications to accept the latter, so this is two spellings of one name and gets the
treatment [`Bic`][bic-value-type] gives its 8- and 11-character forms. `fqdn` rebuilds the explicit
spelling. A bare `.` is left alone rather than stripped, so it fails as an empty label instead of
quietly becoming the empty string.

**Six failure variants, where three is the house average.** Not vocabulary inflation: RFC 1123
genuinely stacks six independent rules, and each one leaves the caller a different thing to do.
Punycode it, fix a character, fix a label, shorten a label, shorten the name, or reach for an
address type. Two of the six branch their message on the payload, the trick
[`Imei`][imei-value-type] uses to name a 16-digit input as an IMEISV rather than call it a miscount.

**`Uri` is not this, measured rather than assumed.** `Uri.parse` accepts `-bad.com`, `bad-.com`,
`a..b.com`, `999.999.999.999` and a 64-character label, and percent-encodes `bücher.example` into
`b%C3%BCcher.example`, which is not what DNS wants. It case-folds and little else, which is the gap
this type fills.

---

<a id="dns-name-value-type"></a>
## DnsName: permissive, but not infinitely so

**RFC 2181 §11 licenses the charset restriction rather than forbidding it.** It says the DNS imposes
only length limits, and that applications using DNS data may add constraints suited to their
purposes. Picking a charset is therefore the clause the standard provides, not a defiance of it. The
invention would be claiming an RFC *requires* the charset.

**Literal any-octet was rejected on the representation, not on taste.** A Dart `String` is UTF-16,
so a type over one cannot honestly promise RFC 2181's octet freedom: it would advertise a
conformance the representation cannot hold, the same objection that made
[`Hostname`](#hostname-value-type) refuse to fake an A-label. It could not safely lower-case either.

**Leading-underscore-only was the tempting middle, and it invents a prohibition.** RFC 8552 §1.1
says an underscored node name begins with an underscore and stops there: it never defines what may
follow, nor rules one out elsewhere in a label. Turning "the convention puts one here" into "one
anywhere else is an error" would make the *permissive* type refuse `a_b.example.com`, which occurs.
So the charset is LDH plus underscore, and `isUnderscored` **reports** an RFC 8552 attribute leaf
rather than gating on one, the way [`Port`](#port-value-type) reports its range.

**Two rules are dropped, not relaxed.** RFC 1123's hyphen-edge and all-numeric-label rules are about
*host names* and RFC 2181 has neither, so `-bad.example.com` and `192.168.1.1` both parse here.
Worth stating precisely, because the numeric rule only ever inspected the **last** label:
`4.3.2.1.in-addr.arpa` was always a valid `Hostname`, `arpa` being alphabetic. Reverse DNS never
needed this type; underscored names did.

**Case-folding survives because the charset is bounded.** RFC 1035 §2.3.3 makes DNS comparison
case-insensitive, so lower-casing matches `Hostname`. On arbitrary octets "lower-case" has no single
meaning, which is the second argument for bounding the charset.

**The conversion is asymmetric, and both directions live here.** `fromHostname` is total and
constructs directly, its input being already normalised and strictly inside these rules;
`tryToHostname` is a parse. Both sit on `DnsName` because `Hostname` shipped first and stays unaware
of it, the same call [`Probability`][probability-constraint-type] made about `Percentage`.

**The shared DNS rules moved to `network/standards/dns_names.dart`** when this type landed. The
63/253 limits, the root-dot fold and the ASCII gate were about to exist twice, and the strict and
permissive types drifting on a limit is the failure that file guards against.

---

<a id="ip-address-value-type"></a>
## IpAddress: a wrapped engine, but not a wrapped grammar

**The engine does the arithmetic; minted does the grammar.**
[`ipaddr`](https://pub.dev/packages/ipaddr) was picked on the usual bar (pure Dart, MIT, zero
dependencies, `platform:web`, current) and it implements RFC 5952 compression correctly, including
the rule most hand-rolled versions miss: `::` must not shorten a *single* zero field. What it does
not do is validate. Its octet and hextet gates are a bare `int.tryParse`, which accepts a sign and
trims whitespace, so `192.168.+1.1`, `192.168.-0.1` and `192.168. 1.1` are all addresses as far as
it is concerned. So the split is: the engine expands `::`, renders RFC 5952 and will do the netmask
maths for `Cidr`, and minted owns the character-level grammar in front of it. Wrapping a package
does not have to mean inheriting its leniency, and the wrapper was translating its throws into a
`ParseOutcome` anyway.

**A leading zero is refused, not read, and that one is a security decision.** `inet_aton` reads
`010` as octal 8; almost everything else reads decimal 10. Python's `ipaddress` accepted it until
3.9.5, and CVE-2021-29921 exists because one component filtering `010` and another connecting to it
disagree about which host was meant. Refusing costs nothing, since no correct writer of an address
pads it.

**One type for both families, with the family reported.** Same call as
[`MacAddress`](#mac-address-value-type) makes for its two widths: one type, never converted, a
getter saying which you hold, and the two never equal. Two types would let the compiler refuse
`v4Network.contains(v6Address)`, which one type can only answer `false` at runtime. That is the
accepted cost of not tripling the surface, and it is documented where it bites rather than left to
be discovered.

**IPv4-mapped addresses keep their mixed spelling**, `::ffff:192.0.2.1`, which RFC 5952 §5 asks for
on that well-known prefix. The engine helps in neither direction: it cannot parse the mixed form at
all, and renders the mapped range as plain hextets. So minted folds the IPv4 tail into two hextets
on the way in and restores it on the way out. The mapped test is on the address *value*, not its
text: `0:0:0:0:ffff:0:0:0` also renders with a leading `::ffff:` and is not mapped, so a string
check would mis-render it as `::ffff:0.0.0.0`.

**Ordering packs to a number.** Comparing the canonical text would put `192.0.2.10` before
`192.0.2.9`, since `1` sorts before `9`. So `compareTo` orders by family, then by the address as one
integer, which is the order anyone sorting a firewall list expects.

**`isLoopback` and `isPrivate` ship; a vendor-style lookup does not.** RFC 1918, RFC 4193's
`fc00::/7`, `127.0.0.0/8` and `::1` are fixed in their RFCs rather than registry-shaped, so they
carry no [clock][registry-data-ships-a-clock], and they are the two questions people currently
answer with a `startsWith('192.168.')`. Anything needing an arbitrary range is `Cidr.contains`,
which composes instead of growing a getter per block.

**What `Digit` and `Digits` are not doing here, since the question comes up.** An octet is a value,
not digit text, so `fromOctets` takes a `Uint8List` like [`MacAddress`](#mac-address-value-type) and
`Uuid` do. Using `Digits` as the internal strictness gate would reject the signs and whitespace
above, but so does one regex, and a layer catching nothing the simpler layer catches is the layer to
cut. The bounded-int types are no better a fit: an octet is 0-255, a hextet 0-65535, a prefix length
0-32 or 0-128, a port 0-65535, all bounded at *both* ends, where a non-negative int is bounded only
below. Dogfooding pays here through composition instead: `Cidr` taking an `IpAddress`.

---

<a id="cidr-value-type"></a>
## Cidr: a block that masks, not a string that starts with

**The bug this type exists for is `startsWith`.** An allow-list holding `'10.0.0.0/8'` as a string
gets tested with a prefix match, and a prefix match says `100.0.0.1` is inside it. Containment is a
question about bits, and the only way to answer it is to mask both sides and compare, which is what
this type does and what a `String` cannot.

**Host bits are refused, not masked.** `192.168.1.5/24` fails rather than becoming `192.168.1.0/24`.
Masking is what most tooling does and it would match the normalise-on-parse pattern used everywhere
else here, but it loses to the rule [`GeoCoordinate`][geo-coordinate-value-type] already states for
altitude: a parse that silently loses part of its input is not a parse. The caller wrote a host
address, and quietly returning a different value than they typed is how a firewall rule ends up
meaning something nobody reviewed. The failure carries the block they most likely meant, so the
remedy is in the error rather than left as an exercise. The address-with-prefix concept is a
genuinely different type, which Python calls `ip_interface`, and can follow if anyone wants it.

**It holds an [`IpAddress`](#ip-address-value-type), and that is the whole point.** This was the
first type to follow [compose from modelled parts][compose-from-modelled-parts], which uses it as
its worked example. What the composition buys here specifically: the mask is already applied, since
parsing guarantees the host bits are clear, so `network.octets` *is* the masked network part and
containment is one comparison rather than two maskings.

**The engine does nothing here, and that is worth recording.** `ipaddr` earns its place inside
[`IpAddress`](#ip-address-value-type), where it expands `::` and renders RFC 5952. Its network types
have no containment test at all, and the one its README shows is `addresses.contains(…)`, a scan
over a lazy iterable: 16.7 million allocations for a `/8`, and no termination at all for a v6 block.
Netmask-from-prefix and the host-bits check are elementary bit maths on octets this package already
exposes, so `Cidr` adds no dependency surface of its own.

**`lastAddress`, not `broadcast`.** IPv6 has no broadcast at all; it uses multicast. `ipaddr` and
Python both call the top of a block its broadcast address, which is a misnomer inherited from IPv4
and one this package need not repeat, for the same reason `prefix24` declines the name
[`oui`](#mac-address-value-type). `netmask` and `hostmask` are absent for a different reason: nobody
writes a v6 netmask, and `contains` makes both unnecessary.

**One notation in, one out.** `address/prefixLength` and nothing else, so a dotted netmask
(`/255.255.255.0`, which the engine would accept) and a bare address with no prefix are both
refused. The prefix goes through the same digits-only gate as the address, since `ipaddr`'s
`_makePrefix` is another bare `int.tryParse` and would take `/+24`, `/ 24` and `/-0`. A leading zero
on the prefix *is* accepted and folds to the plain number, unlike a leading zero in an address:
`/024` carries none of the octal ambiguity that makes `010` dangerous in an octet.

**A family mismatch answers `false` rather than refusing to compile.** That is the accepted cost of
[one address type for both families](#ip-address-value-type). Two types would have let the compiler
reject `v4Block.contains(v6Address)` outright; one type can only answer it at runtime. Documented on
`contains` rather than left to be discovered.

---

<a id="port-value-type"></a>
## Port: a domain that borrows a width

**It borrows [`Uint16`][constraint-types]'s bound instead of restating it.** A port is `0`-`65535`,
exactly a 16-bit field, so `Port.tryFrom` delegates and adds no check of its own. The alternative
was a local `65535`, which is the duplication `IpAddress`'s octet bound was already folded into
`Uint8` for. Note this only works because the ranges are *identical*: `Digit` declined the same
trick over `Uint4`, since `0`-`9` sits strictly inside `0`-`15` and the nibble would have caught
nothing.

**It `implements Uint16` rather than aliasing it.** The subtype relation is real, since every port
is a valid 16-bit value, and it buys the one-directional conversion: a `Port` goes where a `Uint16`
is wanted, never the reverse. An alias would have gone further and made them interchangeable, which
is the mistake [a width is not a domain][constraint-types] warns about: an IPv6 hextet is
`0`-`65535` too, and it is not a port.

**Not a `Uint16` representation.** Holding one would make `.value` a `Uint16`, so reading the number
becomes `port.value.value`, against the contract's rule that `.value` *is* the canonical form. The
representation stays an `int`; only the validation is borrowed.

**Port `0` is accepted, and named rather than refused.** It is a real member of the range, and
`bind(0)` asking the OS for a free port is ordinary. Rejecting it would have cost the exact-`Uint16`
alignment above and pushed callers into modelling "any port" separately, for a value the type can
simply describe. `isWildcard` does the describing, since RFC 6335 gives `0` no name of its own,
listing it among the reserved values "at the edges of each range".

**`range` reports, it does not gate.** The RFC 6335 bands are an IANA assignment policy, not a
validity rule, so a `PortRange` is read back the way `MacAddress` reads its I/G and U/L bits. Gating
on it would refuse ports that work.

**It lives in `network/`, and that is what killed path-based detection.** Filing it by domain broke
the scheme described [below][constraint-types]. Rather than move the type to suit the tooling, the
category became a documented convention. A type's home follows the domain, not the test.

[appendix-md]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md
[bic-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_finance/APPENDIX.md#bic-value-type
[codestyle-md]: https://github.com/LahaLuhem/minted/blob/main/CODESTYLE.md
[compose-from-modelled-parts]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#compose-from-modelled-parts
[constraint-types]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_constraints/APPENDIX.md#constraint-types
[date-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_chronology/APPENDIX.md#date-value-type
[geo-coordinate-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_geography/APPENDIX.md#geo-coordinate-value-type
[gtin-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/APPENDIX.md#gtin-value-type
[imei-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/APPENDIX.md#imei-value-type
[isbn-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/APPENDIX.md#isbn-value-type
[isni-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/APPENDIX.md#isni-value-type
[probability-constraint-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_constraints/APPENDIX.md#probability-constraint-type
[registry-data-ships-a-clock]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#registry-data-ships-a-clock
[uuid-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/APPENDIX.md#uuid-value-type
