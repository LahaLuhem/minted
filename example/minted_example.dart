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

  // `parse` throws a typed exception; `tryParse` would return null instead.
  try {
    Iban.parse('GB29NWBK60161331926818'); // corrupted final digit
  } on MintedFormatException catch (ex) {
    print(ex.message); // Invalid Iban: failed IBAN structure or mod-97 check
  }
}
