// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted/minted.dart';

void main() {
  // Parse, don't validate: an `Email` exists only if it is well-formed.
  final email = Email.parse('Jane.Doe@Example.COM');
  print(email.value); // Jane.Doe@example.com  (domain lower-cased)
  print(email.domain); // example.com
  print(email.mailtoUri); // mailto:Jane.Doe@example.com

  print(Email.tryParse('not-an-email')); // null

  // `Iban` is validated against structure, country, length, and mod-97, then
  // normalised to its compact form.
  final iban = Iban.parse('gb29 nwbk 6016 1331 9268 19');
  print(iban.value); // GB29NWBK60161331926819
  print(iban.countryCode); // GB
  print(iban.formatted); // GB29 NWBK 6016 1331 9268 19

  // `PhoneNumber` normalises to E.164. National-format input needs a region
  // `+`-international input does not.
  final phone = PhoneNumber.parse('0 655 5705 76', region: 'FR');
  print(phone.value); // +33655570576
  print(phone.type); // PhoneNumberType.mobile
  print(phone.telUri); // tel:+33655570576

  // `Date` is the calendar date `DateTime` doesn't model: no time, no zone. It
  // rejects impossible dates instead of rolling them over the way `DateTime` does.
  final date = Date.parse('2026-07-07');
  print(date.iso8601); // 2026-07-07
  print(date.month.daysIn(2026)); // 31  (the month is a Month, and knows its length)
  print(date.addDays(30)); // Date(2026-08-06)
  print(date.isBefore(Date(2027))); // true
  print(Date.tryParse('2026-13-01')); // null (no 13th month)

  // `Uuid` types an existing UUID (the `uuid` package generates them). Case, a `urn:uuid:`
  // prefix, and surrounding braces are normalised to the bare lowercase form.
  final id = Uuid.parse('URN:UUID:F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6');
  print(id.value); // f81d4fae-7dec-11d0-a765-00a0c91e6bf6
  print(id.version); // 1  (version and variant read back as fields)
  print(id.variant); // UuidVariant.rfc9562
  print(Uuid.tryParse('not-a-uuid')); // null

  // `parse` throws a typed exception; `tryParse` would return null instead.
  try {
    Iban.parse('GB29NWBK60161331926818'); // corrupted final digit
  } on MintedFormatException catch (ex) {
    print(ex.message); // Invalid Iban: failed IBAN structure or mod-97 check
  }
}
