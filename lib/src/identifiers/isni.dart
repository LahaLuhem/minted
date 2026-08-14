// A validated ISNI is ASCII digits, plus at most a trailing X.
// ignore_for_file: avoid-substring

import '../numerics/digits.dart';
import '../shared/check_digits/doubling_mod11_check_character.dart';
import '../shared/normalisation/normalisation.dart';
import '../shared/outcomes/parse_outcome.dart';
import 'failures/isni_failure.dart';

/// An ISNI (International Standard Name Identifier): validated for the sixteen-character length,
/// the charset, and the ISO 7064 MOD 11-2 check character. Identifies a public identity: a person,
/// a pseudonym, or an organisation.
/// Standard: [ISO 27729](https://www.isni.org/).
///
/// Normalisation on parse: spaces and hyphens are stripped and a trailing `x` is upper-cased, so
/// [value] is always the compact form. [formatted] rebuilds the spaced grouping ISNI prints.
///
/// An ORCID iD is an ISNI from ORCID's allocated block, so it parses here and [isInOrcidBlock] says
/// so. Why there is no separate `Orcid`: `APPENDIX.md#isni-value-type`.
///
/// {@example /example/minted_example.dart#isni}
extension type const Isni._(String value) {
  /// Builds an [Isni] from [bodyDigits], the fifteen digits before the check character, computing
  /// that character, reporting the [IsniFailure] when they don't form a valid ISNI.
  static ParseOutcome<IsniFailure, Isni> fromBody(Digits bodyDigits) {
    final body = bodyDigits.asString;
    final assembledIsni = '$body${doublingMod11CheckCharacter(body)}';
    final failure = _failureFor(assembledIsni);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(assembledIsni));
  }

  /// Parses [input] as an ISNI, or returns `null` when it fails the length, character, or check
  /// tests.
  static Isni? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an ISNI, reporting the [IsniFailure] that says which check failed.
  static ParseOutcome<IsniFailure, Isni> parse(String input) {
    final compactInput = compactUpperCase(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(compactInput));
  }

  /// The four groups of four ISNI prints, e.g. `0000 0001 2103 2683`.
  // No length guard, unlike Iban.formatted: an ISNI is always sixteen, so every group is full.
  String get formatted => Iterable.generate(
    _length ~/ _groupSize,
    (group) => value.substring(group * _groupSize, (group + 1) * _groupSize),
  ).join(' ');

  /// The final character, the check over the other fifteen. A `String` rather than a `Digit`,
  /// because the value ten is spelled `X`.
  String get checkCharacter => value.substring(_checkCharacterIndex);

  /// Whether this ISNI sits in ORCID's allocated block, so it is also an ORCID iD. Reported rather
  /// than gated, because the block grows.
  // Compared as text: sixteen digits overflow the web's safe integer range, and equal-length
  // zero-padded strings order the same way the numbers do.
  bool get isInOrcidBlock =>
      value.compareTo(_orcidBlockStart) >= 0 && value.compareTo(_orcidBlockEnd) <= 0;

  // Why already-compacted input is not an ISNI, or null when it is one. The single gate parse and
  // fromBody funnel through; widest check first, so the earliest wrong thing is named.
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
  // ORCID's allocated block, as published: 0000-0001-5000-0000 through 0000-0003-5000-0001.
  static const _orcidBlockStart = '0000000150000000';
  static const _orcidBlockEnd = '0000000350000001';
}
