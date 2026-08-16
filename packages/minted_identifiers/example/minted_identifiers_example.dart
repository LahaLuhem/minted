// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted_identifiers/minted_identifiers.dart';

void main() {
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
  print(imei.tac.asString); // 35209900  (a Digits: which model, not which unit)
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

  // `Isni` covers ORCID iDs too, since ORCID issues from a block inside the ISNI range. The block
  // is reported, not gated: refusing everything outside it would refuse most of the standard.
  // #region isni
  final isni = Isni.tryParse('0000-0002-1825-0097')!;
  print(isni.value); // 0000000218250097  (separators stripped)
  print(isni.formatted); // 0000 0002 1825 0097
  print(isni.isInOrcidBlock); // true
  print(Isni.tryParse('0000 0001 2103 2683')?.isInOrcidBlock); // false (an ISNI, not an ORCID iD)
  // #endregion
}
