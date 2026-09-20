// Both wrappers are ASCII, so slicing them off by length is byte-safe.
// ignore_for_file: avoid-substring

part of '../uuid.dart';

String _unwrap(String lowerInput) {
  if (lowerInput.startsWith(_urnPrefix)) return lowerInput.substring(_urnPrefix.length);
  if (lowerInput.startsWith(_braceOpen) && lowerInput.endsWith(_braceClose)) {
    return lowerInput.substring(_braceOpen.length, lowerInput.length - _braceClose.length);
  }

  return lowerInput;
}

final _canonical = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

const _versionIndex = 14;
const _variantIndex = 19;
const _byteCount = 16;
// Cut points around the 4-2-2-2-6 byte groups behind the 8-4-4-4-12 hex.
const _groupByteBoundaries = [0, 4, 6, 8, 10, _byteCount];
const _urnPrefix = 'urn:uuid:';
const _braceOpen = '{';
const _braceClose = '}';
const _rfc9562VariantFloor = 0x8;
const _microsoftVariantFloor = 0xc;
const _futureVariantFloor = 0xe;
