// A validated ISNI is ASCII digits, plus at most a trailing X.
// ignore_for_file: avoid-substring

import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'check_digits/doubling_mod11_check_character.dart';
import 'failures/isni_failure.dart';

/// An ISNI (International Standard Name Identifier): names a public identity, so a person, a pen name,
/// or an organisation. Standard: [ISO 27729](https://www.isni.org/).
///
/// Parsing strips spaces and hyphens and upper-cases a trailing `x`, so [value] is the compact form.
/// [formatted] puts the spaced grouping back.
///
/// An ORCID iD is an ISNI out of ORCID's block, so it parses here and [isInOrcidBlock] says so. Why
/// there's no separate `Orcid`: `APPENDIX.md#isni-value-type`.
///
/// {@example /example/minted_identifiers_example.dart#isni}
extension type const Isni._(String value) {
  /// Builds an [Isni] from [bodyDigits], the 15 before the check character, working that character
  /// out.
  static ParseOutcome<IsniFailure, Isni> fromBody(Digits bodyDigits) {
    final body = bodyDigits.asString;
    final assembledIsni = '$body${doublingMod11CheckCharacter(body)}';
    final failure = _failureFor(assembledIsni);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(assembledIsni));
  }

  /// Parses [input], or `null` if it isn't an ISNI.
  static Isni? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [IsniFailure] that says what went wrong.
  static ParseOutcome<IsniFailure, Isni> parse(String input) {
    final compactInput = compactUpperCase(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(compactInput));
  }

  /// The 4 groups of 4 ISNI prints, like `0000 0001 2103 2683`.
  // No length guard, unlike Iban.formatted: an ISNI is always 16, so every group is full.
  String get formatted => Iterable.generate(
    _length ~/ _groupSize,
    (group) => value.substring(group * _groupSize, (group + 1) * _groupSize),
  ).join(' ');

  /// The last character. A `String`, not a `Digit`, because 10 is spelled `X`.
  String get checkCharacter => value.substring(_checkCharacterIndex);

  /// Whether this sits in ORCID's block. Reported, not gated, because the block grows.
  // Compared as text: 16 digits overflow the web's safe integer range, and equal-length zero-padded
  // strings sort the same way the numbers do.
  bool get isInOrcidBlock =>
      value.compareTo(_orcidBlockStart) >= 0 && value.compareTo(_orcidBlockEnd) <= 0;

  // The one gate parse and fromBody both go through. Widest check first, so the earliest wrong thing
  // gets named.
  static IsniFailure? _failureFor(String compactInput) => switch (compactInput) {
    _ when compactInput.length != _length => IsniWrongLength(compactInput.length),
    _ when !_isniForm.hasMatch(compactInput) => const IsniInvalidCharacters(),
    _ when !_checksumHolds(compactInput) => const IsniChecksumFailed(),
    _ => null,
  };

  static bool _checksumHolds(String compactInput) => compactInput.endsWith(
    doublingMod11CheckCharacter(compactInput.substring(0, _checkCharacterIndex)),
  );

  static final _isniForm = RegExp(r'^\d{15}[\dX]$');

  static const _length = 16;
  static const _groupSize = 4;
  static const _checkCharacterIndex = 15;
  // ORCID's block as published: 0000-0001-5000-0000 through 0000-0003-5000-0001.
  static const _orcidBlockStart = '0000000150000000';
  static const _orcidBlockEnd = '0000000350000001';
}
