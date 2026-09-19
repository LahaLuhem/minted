// A validated ISSN is ASCII digits, plus at most a trailing X.
// ignore_for_file: avoid-substring

import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'check_digits/mod11_check_character.dart';
import 'failures/issn_failure.dart';

/// An ISSN (International Standard Serial Number): names a serial title, not one issue of it. Standard:
/// [ISO 3297](https://www.issn.org/understanding-the-issn/what-is-an-issn/).
///
/// Parsing strips spaces, upper-cases a trailing `x`, and puts the hyphen after the 4th character,
/// so [value] is always `NNNN-NNNC`. The hyphen counts as part of the canonical form because ISO 3297
/// pins it to one spot, unlike an ISBN's groups. [compact] drops it again.
///
/// No ISSN-L, the linking ISSN that ties a title's print and online numbers together. It needs the ISSN
/// Register.
///
/// {@example /example/minted_identifiers_example.dart#issn}
extension type const Issn._(String value) {
  /// Builds an [Issn] from [bodyDigits], the 7 before the check character, working that character
  /// out.
  static ParseOutcome<IssnFailure, Issn> fromBody(Digits bodyDigits) {
    final body = bodyDigits.asString;
    final assembledIssn = '$body${mod11CheckCharacter(body)}';
    final failure = _failureFor(assembledIssn);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(_hyphenated(assembledIssn)));
  }

  /// Parses [input], or `null` if it isn't an ISSN.
  static Issn? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [IssnFailure] that says what went wrong.
  static ParseOutcome<IssnFailure, Issn> parse(String input) {
    final compactInput = compactUpperCase(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(_hyphenated(compactInput)));
  }

  /// The 8 characters without the hyphen, for a URL or a database key.
  String get compact => value.replaceAll(hyphen, '');

  /// The last character. A `String`, not a `Digit`, because ISO 3297 spells 10 as `X`.
  String get checkCharacter => value.substring(_checkCharacterIndex);

  static String _hyphenated(String compactInput) =>
      '${compactInput.substring(0, _groupSize)}$hyphen${compactInput.substring(_groupSize)}';

  // The one gate parse and fromBody both go through. Widest check first, so the earliest wrong thing
  // gets named.
  static IssnFailure? _failureFor(String compactInput) => switch (compactInput) {
    _ when compactInput.length != _length => IssnWrongLength(compactInput.length),
    _ when !_issnForm.hasMatch(compactInput) => const IssnInvalidCharacters(),
    _ when !_checksumHolds(compactInput) => const IssnChecksumFailed(),
    _ => null,
  };

  static bool _checksumHolds(String compactInput) =>
      compactInput.endsWith(mod11CheckCharacter(compactInput.substring(0, _bodyLength)));

  static final _issnForm = RegExp(r'^\d{7}[\dX]$');

  static const _length = 8;
  static const _bodyLength = 7;
  static const _groupSize = 4;
  static const _checkCharacterIndex = 8; // past the hyphen, so one further than in the compact form
}
