// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted_contact/minted_contact.dart';

void main() {
  // Parse, don't validate: an `Email` exists only if it is well-formed.
  // #region email
  final email = Email.tryParse('Jane.Doe@Example.COM')!;
  print(email.value); // Jane.Doe@example.com  (domain lower-cased)
  print(email.domain); // example.com
  print(email.mailtoUri); // mailto:Jane.Doe@example.com

  print(Email.tryParse('not-an-email')); // null
  // #endregion

  // `PhoneNumber` normalises to E.164. National-format input needs a region
  // `+`-international input does not.
  // #region phone
  final phone = PhoneNumber.tryParse('0 655 5705 76', region: 'FR')!;
  print(phone.value); // +33655570576
  print(phone.type); // PhoneNumberType.mobile
  print(phone.telUri); // tel:+33655570576
  // #endregion
}
