// Deprecated for 2.0.0 but still shipping in 1.x, so the tests stay until removal; see #44.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import 'support/bdd.dart';

/// Stands in for a real `parse` until the value types return outcomes: even lengths succeed.
ParseOutcome<EmailFailure, int> lengthOf(String input) =>
    input.length.isEven ? ParseSuccess(input.length) : const ParseFailure(EmailFailure.malformed);

void main() {
  feature('ParseOutcome', () {
    // Typed as the sealed base, which is what `parse` will hand back.
    const ParseOutcome<EmailFailure, int> success = ParseSuccess(4);
    const ParseOutcome<EmailFailure, int> failure = ParseFailure(EmailFailure.malformed);

    scenario('the two arms report which they are', () {
      check(success.isSuccess).isTrue();
      check(success.isFailure).isFalse();
      check(failure.isFailure).isTrue();
      check(failure.isSuccess).isFalse();
    });

    scenario('getOrNull and reasonOrNull are duals, each null on the other arm', () {
      check(success.getOrNull()).equals(4);
      check(success.reasonOrNull).isNull();
      check(failure.getOrNull()).isNull();
      check(failure.reasonOrNull).equals(EmailFailure.malformed);
    });

    scenario('fold collapses either arm to one type', () {
      check(success.fold((reason) => reason.message, (value) => 'got $value')).equals('got 4');
      check(failure.fold((reason) => reason.message, (value) => 'got $value'))
          .equals('not a well-formed email address');
    });

    scenario('getOrElse supplies a fallback only on failure', () {
      check(success.getOrElse(() => 99)).equals(4);
      check(failure.getOrElse(() => 99)).equals(99);
    });

    scenario('getOrThrow passes a value through and throws the typed failure otherwise', () {
      check(success.getOrThrow()).equals(4);
      check(failure.getOrThrow).throws<MintedFormatException>();
    });

    // The whole reason it exists over `getOrNull()!`: the typed reason survives, so a violated
    // claim-in-source says which type refused and why instead of "null check on a null value".
    scenario('getOrThrow keeps the reason that getOrNull would have discarded', () {
      check(failure.getOrThrow)
          .throws<MintedFormatException>()
          .has((error) => error.failure, 'failure')
          .equals(EmailFailure.malformed);

      check(failure.getOrThrow)
          .throws<MintedFormatException>()
          .has((error) => error.message, 'message')
          .equals('Invalid Email: not a well-formed email address');
    });

    // It has the failure but never the text that produced it, so source stays null rather than
    // being invented.
    scenario('getOrThrow reports no source, having never seen the input', () {
      check(failure.getOrThrow)
          .throws<MintedFormatException>()
          .has((error) => error.source, 'source')
          .isNull();
    });

    scenario('map transforms a value and carries a failure across untouched', () {
      check(success.map((value) => value * 2)).equals(const ParseSuccess(8));
      check(failure.map((value) => value * 2))
          .equals(const ParseFailure<EmailFailure, int>(EmailFailure.malformed));
    });

    scenario('flatMap chains a fallible step, and the first failure short-circuits', () {
      check(lengthOf('abcd').flatMap((value) => lengthOf('x' * value)))
          .equals(const ParseSuccess(4));
      check(lengthOf('abc').flatMap((_) => lengthOf('xx')))
          .equals(const ParseFailure<EmailFailure, int>(EmailFailure.malformed));
    });

    scenario('a switch over the two arms is exhaustive, and destructures', () {
      // No default arm: the compiler accepting this is the guarantee being tested.
      String describe(ParseOutcome<EmailFailure, int> outcome) => switch (outcome) {
        ParseSuccess(:final value) => 'ok $value',
        ParseFailure(:final reason) => 'no: ${reason.message}',
      };

      check(describe(success)).equals('ok 4');
      check(describe(failure)).startsWith('no: ');
    });

    scenario('outcomes are equal by their contents, and hash together', () {
      check(success).equals(const ParseSuccess<EmailFailure, int>(4));
      check(success.hashCode).equals(const ParseSuccess<EmailFailure, int>(4).hashCode);
      check(failure).equals(const ParseFailure<EmailFailure, int>(EmailFailure.malformed));
      check(failure.hashCode)
          .equals(const ParseFailure<EmailFailure, int>(EmailFailure.malformed).hashCode);
      check(success).not((it) => it.equals(const ParseSuccess<EmailFailure, int>(5)));
    });

    scenario('a success and a failure are never equal', () {
      check(success).not((it) => it.equals(failure));
    });

    scenario('both arms render their contents, not Instance of', () {
      check(success.toString()).equals('ParseSuccess(4)');
      check(failure.toString()).equals('ParseFailure(EmailFailure.malformed)');
    });

    scenario('an extension type survives as the success value', () {
      // Extension types erase to their representation, so this pins that T works for them too.
      final outcome = ParseSuccess<DigitFailure, Digit>(Digit.from(7));

      check(outcome.getOrNull()?.value).equals(7);
    });
  });
}
