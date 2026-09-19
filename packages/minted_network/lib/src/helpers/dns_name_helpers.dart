part of '../dns_name.dart';

final _allowed = RegExp('[0-9a-z._-]');

const _underscore = '_';

// Ordered so each check can assume the ones before it passed.
DnsNameFailure? _failureFor(String normalisedInput) {
  final offendingCharacter = _offendingCharacter(normalisedInput);
  if (offendingCharacter != null) {
    return isNonAscii(offendingCharacter)
        ? const DnsNameNotAscii()
        : DnsNameInvalidCharacter(offendingCharacter);
  }
  if (normalisedInput.length > maxNameLength) return DnsNameTooLong(normalisedInput.length);

  final labels = normalisedInput.split(labelSeparator);
  if (labels.any((label) => label.isEmpty)) return const DnsNameLabelEmpty();

  final overlongLabel = labels.firstWhereOrNull((label) => label.length > maxLabelLength);

  return overlongLabel != null ? DnsNameLabelTooLong(overlongLabel.length) : null;
}

// The first character that is neither a label character nor the separator, or null when all pass.
String? _offendingCharacter(String normalisedInput) =>
    normalisedInput.split('').firstWhereOrNull((character) => !_allowed.hasMatch(character));
