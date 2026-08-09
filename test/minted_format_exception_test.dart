import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import 'support/bdd.dart';

void main() {
  feature('MintedFormatException', () {
    scenario('from renders the failure type name and message', () {
      check(
        MintedFormatException.from(EmailFailure.malformed, 'x').message,
      ).equals('Invalid Email: not a well-formed email address');
      check(
        MintedFormatException.from(MonthFailure.notAMonth, 'x').message,
      ).equals('Invalid Month: not a month number 1-12');
    });

    scenario('from carries the offending input as its source', () {
      check(
        MintedFormatException.from(EmailFailure.malformed, 'bad-input').source as String?,
      ).equals('bad-input');
    });

    scenario('from carries the typed failure, so a caller can switch on the cause', () {
      check(
        MintedFormatException.from(const IbanChecksumFailed(), 'x').failure,
      ).equals(const IbanChecksumFailed());
    });

    scenario('it extends FormatException, so on FormatException catches parse failures', () {
      check(() => Email.parse('nope')).throws<FormatException>();
    });
  });
}
