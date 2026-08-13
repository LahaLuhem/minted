// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted/minted.dart';

void main() {
  // Parse, don't validate: an `Email` exists only if it is well-formed.
  // #region email
  final email = Email.tryParse('Jane.Doe@Example.COM')!;
  print(email.value); // Jane.Doe@example.com  (domain lower-cased)
  print(email.domain); // example.com
  print(email.mailtoUri); // mailto:Jane.Doe@example.com

  print(Email.tryParse('not-an-email')); // null
  // #endregion

  // `Iban` is validated against structure, country, length, and mod-97, then
  // normalised to its compact form.
  // #region iban
  final iban = Iban.tryParse('gb29 nwbk 6016 1331 9268 19')!;
  print(iban.value); // GB29NWBK60161331926819
  print(iban.countryCode); // GB
  print(iban.formatted); // GB29 NWBK 6016 1331 9268 19
  // #endregion

  // `PhoneNumber` normalises to E.164. National-format input needs a region
  // `+`-international input does not.
  // #region phone
  final phone = PhoneNumber.tryParse('0 655 5705 76', region: 'FR')!;
  print(phone.value); // +33655570576
  print(phone.type); // PhoneNumberType.mobile
  print(phone.telUri); // tel:+33655570576
  // #endregion

  // `Date` is the calendar date `DateTime` doesn't model: no time, no zone. It
  // rejects impossible dates instead of rolling them over the way `DateTime` does.
  // #region date
  final date = Date.tryParse('2026-07-07')!;
  print(date.iso8601); // 2026-07-07
  print(date.month.daysIn(2026)); // 31  (the month is a Month, and knows its length)
  print(date.addDays(30)); // Date(2026-08-06)
  print(date.isBefore(Date(2027))); // true
  print(Date.tryParse('2026-13-01')); // null (no 13th month)
  // #endregion

  // `Iso8601Duration` holds components, because a month has no length until anchored to a date.
  // #region iso8601Duration
  final span = Iso8601Duration.tryParse('P1Y2M3DT4H')!;
  print(span.iso8601); // P1Y2M3DT4H
  print(span.months); // 2
  print(span.toDuration(from: Date(2026, 1, 31))); // 10252:00:00.000000  (427 days and 4 hours)
  print(Iso8601Duration.tryParse('P1M')!.toDuration(from: Date(2026, 2))); // 672:00:00 (28 days)
  print(Iso8601Duration.tryParse('PT1M')!.iso8601); // PT1M  (a minute; P1M is a month)
  print(Iso8601Duration.parse('P1Y2W').reasonOrNull?.message);
  // the week form PnW cannot carry a "Y" component too
  // #endregion

  // `Uuid` types an existing UUID (the `uuid` package generates them). Case, a `urn:uuid:`
  // prefix, and surrounding braces are normalised to the bare lowercase form.
  // #region uuid
  final id = Uuid.tryParse('URN:UUID:F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6')!;
  print(id.value); // f81d4fae-7dec-11d0-a765-00a0c91e6bf6
  print(id.version); // 1  (version and variant read back as fields)
  print(id.variant); // UuidVariant.rfc9562
  print(Uuid.tryParse('not-a-uuid')); // null
  // #endregion

  // `Isbn` folds both generations into the 13-digit form, so the two spellings of one book are
  // the same value.
  // #region isbn
  final isbn = Isbn.tryParse('0-306-40615-2')!;
  print(isbn.value); // 9780306406157
  print(isbn.isbn10); // 0306406152  (null for a 979 ISBN, which never had one)
  print(Isbn.tryParse('9790260000438')); // null (an ISMN: printed music, not a book)
  // #endregion

  // `Bic` folds the 8-character SWIFT code into the 11-character one, `XXX` being the primary
  // office, so both spellings of one office are the same value.
  // #region bic
  final bic = Bic.tryParse('deut de ff')!;
  print(bic.value); // DEUTDEFFXXX
  print(bic.bic8); // DEUTDEFF  (the short form, rebuilt)
  print(bic == Bic.tryParse('DEUTDEFFXXX')); // true
  print(Bic.tryParse('DEUTZZFF')); // null (ZZ is not a country)
  // #endregion

  // `PaymentCardNumber` is a class rather than an extension type so its rendered form can mask the
  // number: printing one cannot leak a PAN.
  // #region card
  final card = PaymentCardNumber.tryParse('4111 1111 1111 1111')!;
  print(card); // PaymentCardNumber(••••1111)
  print(card.masked); // ••••1111
  print(card.cardScheme); // CardScheme.visa  (read off the prefix, never validated)
  print(PaymentCardNumber.cardSchemesOf('4')); // {CardScheme.visa}  (answers while you type)
  print(PaymentCardNumber.tryParse('4111111111111112')); // null (fails the Luhn check)
  // #endregion

  // `Gtin` folds all four GS1 lengths into the 14-digit form, so a UPC-A and its EAN-13 spelling
  // are the same trade item. Padding is safe: GS1 weights from the right.
  // #region gtin
  final gtin = Gtin.tryParse('036000291452')!;
  print(gtin.value); // 00036000291452
  print(gtin.shortestForm); // 036000291452  (what the barcode carries)
  print(gtin.gtin8); // null (it needs more than eight digits)
  print(Gtin.tryParse('4006381333932')); // null (fails the GS1 mod-10 check)
  // #endregion

  // `Imei` runs the Luhn check the printed grouping hides, and hands back the parts.
  // #region imei
  final imei = Imei.tryParse('35-209900-176148-1')!;
  print(imei.value); // 352099001761481
  print(imei.tac); // 35209900  (which model, not which unit)
  print(imei.formatted); // 35-209900-176148-1
  print(
    Imei.parse('3520990017614810').reasonOrNull?.message,
  ); // 16 digits is an IMEISV, not an IMEI
  // #endregion

  // `Issn` keeps the hyphen, because ISO 3297 fixes it at one position (unlike an ISBN's groups,
  // which come from a range table). Its check character can be `X`, standing for ten.
  // #region issn
  final issn = Issn.tryParse('1050124x')!;
  print(issn.value); // 1050-124X  (hyphen placed, x upper-cased)
  print(issn.compact); // 1050124X  (for a URL or a database key)
  print(issn.checkCharacter); // X
  print(Issn.tryParse('0317-8470')); // null (fails the mod-11 check)
  // #endregion

  // `Isin` runs Luhn over the number with its letters expanded to two digits each, so a letter in
  // the NSIN weighs more characters than it shows.
  // #region isin
  final isin = Isin.tryParse('au0000xvgza3')!;
  print(isin.value); // AU0000XVGZA3
  print(isin.nsin); // 0000XVGZA
  print(isin.hasCountryPrefix); // true
  print(Isin.tryParse('US0378331006')); // null (fails the Luhn check)
  // #endregion

  // `Isni` covers ORCID iDs too, since ORCID issues from a block inside the ISNI range. The block
  // is reported, not gated: refusing everything outside it would refuse most of the standard.
  // #region isni
  final isni = Isni.tryParse('0000-0002-1825-0097')!;
  print(isni.value); // 0000000218250097  (separators stripped)
  print(isni.formatted); // 0000 0002 1825 0097
  print(isni.isInOrcidBlock); // true
  print(Isni.tryParse('0000 0001 2103 2683')?.isInOrcidBlock); // false (an ISNI, not an ORCID iD)
  // #endregion

  // `MacAddress` folds the four notations one address gets written in, so the spelling a device or
  // a log happens to use stops mattering. Both widths parse and neither is mapped onto the other.
  // #region mac
  final mac = MacAddress.tryParse('00-00-5E-00-53-00')!;
  print(mac.value); // 00:00:5e:00:53:00  (canonical: colon-separated, lower-case)
  print(mac.ieee802); // 00-00-5E-00-53-00  (the IEEE hyphen form)
  print(mac.prefix24); // 00:00:5e  (the first three octets, deliberately not called an OUI)
  print(mac.isLocallyAdministered); // false  (the U/L bit, read back rather than gating the parse)
  print(MacAddress.tryParse('0000.5e00.5300') == mac); // true (Cisco dot-quad, same address)
  print(MacAddress.tryParse('0:0:5e:0:53:0')); // null (omitted leading zeros aren't a MAC address)
  // #endregion

  // `GeoCoordinate` names the pair, because a swapped latitude and longitude is a type bug no range
  // check catches. ISO 6709 picks the unit by field width, and all three widths fold to degrees.
  // #region geo
  final eiffelTower = GeoCoordinate.tryParse('+48.8577+002.295/')!;
  print(eiffelTower.latitude); // 48.8577
  print(eiffelTower.iso6709); // +48.8577+002.295/  (canonical form)
  print(eiffelTower.sexagesimal); // 48°51′27.72″N 2°17′42″E  (display form)
  print(GeoCoordinate.tryParse('+5012-00010/')?.latitude); // 50.2  (degrees and minutes)
  print(GeoCoordinate.tryParse('+46+2/')); // null (an unpadded longitude is a different location)
  // #endregion

  // `Hostname` enforces what `Uri` waves through: RFC 1123's grammar and both length limits. Case
  // and a trailing root dot normalise away, so one name has exactly one value.
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

  // `IpAddress` canonicalises per RFC 5952, so the four spellings of one v6 address stop being four
  // map keys. `InternetAddress` cannot do this job: it is `dart:io`, so it is absent on the web.
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

  // `Cidr` holds an `IpAddress` and a prefix length rather than the text, so `contains` masks bits
  // instead of matching a string prefix. The string version calls 100.0.0.1 part of 10.0.0.0/8.
  // #region cidr
  final block = Cidr.tryParse('10.0.0.0/8')!;
  print(block.asString); // 10.0.0.0/8
  print(block.lastAddress.value); // 10.255.255.255
  print(block.contains(IpAddress.tryParse('10.1.2.3')!)); // true
  print(block.contains(IpAddress.tryParse('100.0.0.1')!)); // false (a text prefix match says true)
  print(
    Cidr.parse('192.168.1.5/24').reasonOrNull?.message,
  ); // has host bits set below the prefix; the network is "192.168.1.0/24"
  // #endregion

  // `Port` is exactly a `Uint16`'s range, so that type owns the bound. The RFC 6335 band is read
  // back rather than gated on, the way `MacAddress` reads its bits.
  // #region port
  final port = Port.tryFrom(8080)!;
  print(port.value); // 8080
  print(port.range); // PortRange.user
  print(Port.tryFrom(443)!.range); // PortRange.system  (well-known)
  print(Port.tryFrom(0)!.isWildcard); // true  (bind(0) asks the OS for a free port)
  print(Port.tryFrom(65536)); // null (one past the 16-bit ceiling)
  // #endregion

  // `Uint` and `NaturalNumber` are constraint types: a range over a number with no standard text
  // form, so they take `tryFrom(int)` and no `parse`. Zero is the one value they disagree on.
  // #region quantities
  print(Uint.tryFrom(0)?.value); // 0 (an empty cart is a real count)
  print(NaturalNumber.tryFrom(0)); // null (a page size of zero is not)
  print(Uint.tryFrom(-1)); // null, rather than wrapping to a huge number the way C would
  // #endregion

  // The fixed widths bound both ends, and each width is its own type, so a Uint8 cannot be passed
  // where a Uint4 is wanted.
  // #region fixedwidths
  print(Uint8.tryFrom(255)?.value); // 255
  print(Uint8.tryFrom(256)); // null (refused, not truncated to 0)
  // #endregion

  // `Percentage` is the other kind of constraint type: it bounds nothing, and names the unit,
  // since 15 and 0.15 are both plausible readings of "fifteen percent".
  // #region percentage
  final discount = Percentage.tryFrom(15)!; // the percent, which is what `.value` holds
  print(discount.fraction); // 0.15 (the same proportion, said the other way)
  print(discount.of(200)); // 30.0
  print(Percentage.tryFromFraction(0.29)!.value); // 29.0, where 0.29 * 100 is 28.999999999999996
  print(Percentage.tryFrom(-12)?.value); // -12.0 (churn is real; nothing is bounded)
  print(Percentage.tryFrom(double.nan)); // null (finiteness is the only invariant)
  // #endregion

  // `parse` hands back the reason instead of throwing, so invalid input needs no try/catch.
  final corrupted = Iban.parse('GB29NWBK60161331926818'); // corrupted final digit
  print(corrupted.isFailure); // true
  print(corrupted.reasonOrNull?.message); // failed the mod-97 check

  // The failure says which check failed, so a UI can tell "mistyped" from "unsupported".
  // reasonOrNull is null on success, which makes this the whole of a form-field validator.
  String? ibanError(String input) => switch (Iban.parse(input).reasonOrNull) {
    null => null,
    IbanChecksumFailed() => 'Check the digits, one looks mistyped',
    IbanUnknownCountry(:final countryCode) => 'We do not support IBANs from $countryCode',
    _ => 'That does not look like an IBAN',
  };

  print(ibanError('ZZ29NWBK60161331926819')); // We do not support IBANs from ZZ
  print(ibanError('gb29 nwbk 6016 1331 9268 19')); // null (it is valid)

  // Assembling from parts you assert are valid still throws: calling it is the assertion.
  try {
    Iban.fromComponents(countryCode: 'GB', bban: 'TOOSHORT');
  } on MintedFormatException catch (ex) {
    print(ex.message); // Invalid Iban: expected 22 characters for this country, got 12
  }
}
