// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted_finance/minted_finance.dart';

void main() {
  // `Iban` is validated against structure, country, length, and mod-97, then
  // normalised to its compact form.
  // #region iban
  final iban = Iban.tryParse('gb29 nwbk 6016 1331 9268 19')!;
  print(iban.value); // GB29NWBK60161331926819
  print(iban.countryCode); // GB
  print(iban.formatted); // GB29 NWBK 6016 1331 9268 19
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

  // `Isin` runs Luhn over the number with its letters expanded to two digits each, so a letter in
  // the NSIN weighs more characters than it shows.
  // #region isin
  final isin = Isin.tryParse('au0000xvgza3')!;
  print(isin.value); // AU0000XVGZA3
  print(isin.nsin); // 0000XVGZA
  print(isin.hasCountryPrefix); // true
  print(Isin.tryParse('US0378331006')); // null (fails the Luhn check)
  // #endregion
}
