import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import 'support/bdd.dart';

void main() {
  feature('MintedFormatError', () {
    scenario('from renders the failure type name and message', () {
      check(MintedFormatError.from(EmailFailure.malformed).message)
          .equals('Invalid Email: not a well-formed email address');
      check(MintedFormatError.from(MonthFailure.notAMonth).message)
          .equals('Invalid Month: not a month number 1-12');
    });

    scenario('from carries the typed failure, so a caller can switch on the cause', () {
      check(MintedFormatError.from(const IbanChecksumFailed()).failure)
          .equals(const IbanChecksumFailed());
    });

    scenario('it renders as its message', () {
      check(MintedFormatError.from(const IbanChecksumFailed()).toString())
          .equals('Invalid Iban: failed the mod-97 check');
    });

    // An Error, not an Exception: reaching it means a caller asserted a value was valid and was
    // wrong, which is a bug in their source rather than a condition to catch.
    scenario('it is an Error, so on FormatException no longer catches it', () {
      check(() => Date.of(2026, 13).getOrThrow()).throws<Error>();
      check(MintedFormatError.from(EmailFailure.malformed)).isA<Error>();
      check(MintedFormatError.from(EmailFailure.malformed) is Exception).isFalse();
    });

    scenario('getOrThrow is the only door that raises it', () {
      // Every fallible door reports instead; this is the caller opting in.
      check(Date.of(2026, 13).isFailure).isTrue();
      check(() => Date.of(2026, 13).getOrThrow()).throws<MintedFormatError>();
    });
  });
}
