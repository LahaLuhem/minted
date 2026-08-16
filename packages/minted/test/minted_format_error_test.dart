import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import 'support/bdd.dart';
import 'support/failures.dart';

void main() {
  feature('MintedFormatError', () {
    // A failing outcome built by hand: core declares ParseOutcome but owns no fallible door, so
    // there is no `X.parse` here to produce one. The domain packages cover the real doors.
    const ParseOutcome<TestFailure, int> failed = ParseFailure(TestFailure.malformed);

    scenario('from renders the failure type name and message', () {
      check(MintedFormatError.from(TestFailure.malformed).message)
          .equals('Invalid TestValue: not a well-formed test value');
      check(MintedFormatError.from(const OtherFailure()).message)
          .equals('Invalid OtherValue: failed the other check');
    });

    scenario('from carries the typed failure, so a caller can switch on the cause', () {
      check(MintedFormatError.from(const OtherFailure()).failure).equals(const OtherFailure());
    });

    scenario('it renders as its message', () {
      check(MintedFormatError.from(const OtherFailure()).toString())
          .equals('Invalid OtherValue: failed the other check');
    });

    // An Error, not an Exception: reaching it means a caller asserted a value was valid and was
    // wrong, which is a bug in their source rather than a condition to catch.
    scenario('it is an Error, so on FormatException no longer catches it', () {
      check(failed.getOrThrow).throws<Error>();
      check(MintedFormatError.from(TestFailure.malformed)).isA<Error>();
      check(MintedFormatError.from(TestFailure.malformed) is Exception).isFalse();
    });

    scenario('getOrThrow is the only door that raises it', () {
      // Every fallible door reports instead; this is the caller opting in.
      check(failed.isFailure).isTrue();
      check(failed.getOrThrow).throws<MintedFormatError>();
    });
  });
}
