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
