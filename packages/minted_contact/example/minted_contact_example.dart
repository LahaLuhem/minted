// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted_contact/minted_contact.dart';

void main() {
  // The domain lower-cases, the local-part's case survives.
  // #region email
  final email = Email.tryParse('Jane.Doe@Example.COM')!;
  print(email.value); // Jane.Doe@example.com  (domain lower-cased)
  print(email.domain); // example.com
  print(email.mailtoUri); // mailto:Jane.Doe@example.com

  print(Email.tryParse('not-an-email')); // null

  // A named constant is const, so it reaches where `Email.tryParse(...)!` cannot.
  const escalation = <Email>[EmailConstants.abuse, EmailConstants.security];
  print(escalation.map((mailbox) => mailbox.localPart)); // (abuse, security)
  // #endregion

  // Normalises to E.164. National-format input needs a region hint, international input doesn't.
  // #region phone
  final phone = PhoneNumber.tryParse('0 655 5705 76', region: 'FR')!;
  print(phone.value); // +33655570576
  print(phone.type); // PhoneNumberType.mobile
  print(phone.telUri); // tel:+33655570576

  print(
    PhoneNumberConstants.exampleGb.formatNational(),
  ); // 20 7946 0148  (RFC 6116's own example number)
  // #endregion
}
