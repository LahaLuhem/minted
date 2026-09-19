part of '../hostname.dart';

final _allowed = RegExp('[0-9a-z.-]');

// Ordered so each check can assume the ones before it passed.
HostnameFailure? _failureFor(String normalisedInput) {
  final offendingCharacter = _offendingCharacter(normalisedInput);
  if (offendingCharacter != null) {
    return isNonAscii(offendingCharacter)
        ? const HostnameNotAscii()
        : HostnameInvalidCharacter(offendingCharacter);
  }
  if (normalisedInput.length > maxNameLength) return HostnameTooLong(normalisedInput.length);

  final labels = normalisedInput.split(labelSeparator);
  final malformedLabel = labels.firstWhereOrNull(_isMalformed);
  if (malformedLabel != null) return HostnameLabelMalformed(malformedLabel);

  final overlongLabel = labels.firstWhereOrNull((label) => label.length > maxLabelLength);
  if (overlongLabel != null) return HostnameLabelTooLong(overlongLabel.length);

  return !digitsOnly.hasMatch(labels.last) ? null : const HostnameNumericTld();
}

// The first character that is neither a label character nor the separator, or null when all pass.
String? _offendingCharacter(String normalisedInput) =>
    normalisedInput.split('').firstWhereOrNull((character) => !_allowed.hasMatch(character));

bool _isMalformed(String label) =>
    label.isEmpty || label.startsWith(hyphen) || label.endsWith(hyphen);
