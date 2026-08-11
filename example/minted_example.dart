// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted/minted.dart';

void main() {
  // Parse, don't validate: an `Email` exists only if it is well-formed.
  final email = Email.tryParse('Jane.Doe@Example.COM')!;
  print(email.value); // Jane.Doe@example.com  (domain lower-cased)
  print(email.domain); // example.com
  print(email.mailtoUri); // mailto:Jane.Doe@example.com

  print(Email.tryParse('not-an-email')); // null

  // `Iban` is validated against structure, country, length, and mod-97, then
  // normalised to its compact form.
  final iban = Iban.tryParse('gb29 nwbk 6016 1331 9268 19')!;
  print(iban.value); // GB29NWBK60161331926819
  print(iban.countryCode); // GB
  print(iban.formatted); // GB29 NWBK 6016 1331 9268 19

  // `PhoneNumber` normalises to E.164. National-format input needs a region
  // `+`-international input does not.
  final phone = PhoneNumber.tryParse('0 655 5705 76', region: 'FR')!;
  print(phone.value); // +33655570576
  print(phone.type); // PhoneNumberType.mobile
  print(phone.telUri); // tel:+33655570576

  // `Date` is the calendar date `DateTime` doesn't model: no time, no zone. It
  // rejects impossible dates instead of rolling them over the way `DateTime` does.
  final date = Date.tryParse('2026-07-07')!;
  print(date.iso8601); // 2026-07-07
  print(date.month.daysIn(2026)); // 31  (the month is a Month, and knows its length)
  print(date.addDays(30)); // Date(2026-08-06)
  print(date.isBefore(Date(2027))); // true
  print(Date.tryParse('2026-13-01')); // null (no 13th month)

  // `Uuid` types an existing UUID (the `uuid` package generates them). Case, a `urn:uuid:`
  // prefix, and surrounding braces are normalised to the bare lowercase form.
  final id = Uuid.tryParse('URN:UUID:F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6')!;
  print(id.value); // f81d4fae-7dec-11d0-a765-00a0c91e6bf6
  print(id.version); // 1  (version and variant read back as fields)
  print(id.variant); // UuidVariant.rfc9562
  print(Uuid.tryParse('not-a-uuid')); // null

  // `Isbn` folds both generations into the 13-digit form, so the two spellings of one book are
  // the same value.
  final isbn = Isbn.tryParse('0-306-40615-2')!;
  print(isbn.value); // 9780306406157
  print(isbn.isbn10); // 0306406152  (null for a 979 ISBN, which never had one)
  print(Isbn.tryParse('9790260000438')); // null (an ISMN: printed music, not a book)

  // `Bic` folds the 8-character SWIFT code into the 11-character one, `XXX` being the primary
  // office, so both spellings of one office are the same value.
  final bic = Bic.tryParse('deut de ff')!;
  print(bic.value); // DEUTDEFFXXX
  print(bic.bic8); // DEUTDEFF  (the short form, rebuilt)
  print(bic == Bic.tryParse('DEUTDEFFXXX')); // true
  print(Bic.tryParse('DEUTZZFF')); // null (ZZ is not a country)

  // `PaymentCardNumber` is a class rather than an extension type so its rendered form can mask the
  // number: printing one cannot leak a PAN.
  final card = PaymentCardNumber.tryParse('4111 1111 1111 1111')!;
  print(card); // PaymentCardNumber(••••1111)
  print(card.masked); // ••••1111
  print(card.cardScheme); // CardScheme.visa  (read off the prefix, never validated)
  print(PaymentCardNumber.cardSchemesOf('4')); // {CardScheme.visa}  (answers while you type)
  print(PaymentCardNumber.tryParse('4111111111111112')); // null (fails the Luhn check)

  // `Gtin` folds all four GS1 lengths into the 14-digit form, so a UPC-A and its EAN-13 spelling
  // are the same trade item. Padding is safe: GS1 weights from the right.
  final gtin = Gtin.tryParse('036000291452')!;
  print(gtin.value); // 00036000291452
  print(gtin.shortestForm); // 036000291452  (what the barcode carries)
  print(gtin.gtin8); // null (it needs more than eight digits)
  print(Gtin.tryParse('4006381333932')); // null (fails the GS1 mod-10 check)

  // `Imei` runs the Luhn check the printed grouping hides, and hands back the parts.
  final imei = Imei.tryParse('35-209900-176148-1')!;
  print(imei.value); // 352099001761481
  print(imei.tac); // 35209900  (which model, not which unit)
  print(imei.formatted); // 35-209900-176148-1
  print(
    Imei.parse('3520990017614810').reasonOrNull?.message,
  ); // 16 digits is an IMEISV, not an IMEI

  // `Issn` keeps the hyphen, because ISO 3297 fixes it at one position (unlike an ISBN's groups,
  // which come from a range table). Its check character can be `X`, standing for ten.
  final issn = Issn.tryParse('1050124x')!;
  print(issn.value); // 1050-124X  (hyphen placed, x upper-cased)
  print(issn.compact); // 1050124X  (for a URL or a database key)
  print(issn.checkCharacter); // X
  print(Issn.tryParse('0317-8470')); // null (fails the mod-11 check)

  // `Isin` runs Luhn over the number with its letters expanded to two digits each, so a letter in
  // the NSIN weighs more characters than it shows.
  final isin = Isin.tryParse('au0000xvgza3')!;
  print(isin.value); // AU0000XVGZA3
  print(isin.nsin); // 0000XVGZA
  print(isin.hasCountryPrefix); // true
  print(Isin.tryParse('US0378331006')); // null (fails the Luhn check)

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
