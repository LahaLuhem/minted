// A validated ISSN is ASCII digits, plus at most a trailing X.
// ignore_for_file: avoid-substring

import '../shared/check_digits/mod11_check_character.dart';
import '../shared/minted_format_exception.dart';
import '../shared/parse_outcome.dart';
import 'failures/issn_failure.dart';

/// An ISSN (International Standard Serial Number): validated for characters, the eight-character
/// length, and the ISO 3297 mod-11 check character. Identifies a serial title, not one issue of it.
/// Standard: [ISO 3297](https://www.issn.org/understanding-the-issn/what-is-an-issn/).
///
/// Normalisation on parse: spaces are stripped, a trailing `x` is upper-cased, and the hyphen is placed
/// after the fourth character, so [value] is always the printed `NNNN-NNNC` form. The hyphen belongs
/// to the canonical form because ISO 3297 fixes it at one position, unlike an ISBN's groups.
/// [compact] drops it again for a URL or a database key.
///
/// ISSN-L, the linking ISSN that ties a title's print and online numbers together, needs the ISSN
/// Register and so is out of scope.
extension type const Issn._(String value) {
  /// Builds an [Issn] from [bodyDigits], the seven digits before the check character, computing that
  /// character. Throws [MintedFormatException] when the parts don't form a valid ISSN. For assembling
  /// from a known-valid source.
  static Issn fromBody(String bodyDigits) {
    final compactBody = _compact(bodyDigits);
    final assembledIssn = '$compactBody${mod11CheckCharacter(compactBody)}';
    final failure = _failureFor(assembledIssn);

    return failure != null
        ? throw MintedFormatException.from(failure, bodyDigits)
        : ._(_hyphenated(assembledIssn));
  }

  /// Parses [input] as an ISSN, or returns `null` when it fails the length, character, or check tests.
  static Issn? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an ISSN, reporting the [IssnFailure] that says which check failed.
  static ParseOutcome<IssnFailure, Issn> parse(String input) {
    final compactInput = _compact(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(_hyphenated(compactInput)));
  }

  /// The eight characters without the hyphen, for a URL or a database key.
  String get compact => value.replaceAll(_hyphen, '');

  /// The final character, the mod-11 check over the other seven. A `String` rather than a `Digit`,
  /// because ISO 3297 spells the value ten as `X`.
  String get checkCharacter => value.substring(_checkCharacterIndex);

  static String _compact(String input) => input.replaceAll(_separators, '').toUpperCase();

  // ISO 3297 fixes the hyphen after the fourth character, so it carries no information and is
  // reinserted rather than stored through parsing.
  static String _hyphenated(String compactInput) =>
      '${compactInput.substring(0, _groupSize)}$_hyphen${compactInput.substring(_groupSize)}';

  // Why already-compacted input is not an ISSN, or null when it is one. The single gate parse and
  // fromBody funnel through; widest check first, so the earliest wrong thing is named.
  static IssnFailure? _failureFor(String compactInput) => switch (compactInput) {
    _ when compactInput.length != _length => IssnWrongLength(compactInput.length),
    _ when !_issnForm.hasMatch(compactInput) => const IssnInvalidCharacters(),
    _ when !_checksumHolds(compactInput) => const IssnChecksumFailed(),
    _ => null,
  };

  static bool _checksumHolds(String compactInput) =>
      compactInput.endsWith(mod11CheckCharacter(compactInput.substring(0, _bodyLength)));

  static final _separators = RegExp(r'[\s-]+');
  static final _issnForm = RegExp(r'^\d{7}[\dX]$');

  static const _length = 8;
  static const _bodyLength = 7;
  static const _groupSize = 4;
  static const _checkCharacterIndex = 8; // past the hyphen, so one further than in the compact form
  static const _hyphen = '-';
}
