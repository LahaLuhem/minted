// A validated MAC address is ASCII hex and colons only, so slicing by index is byte-safe.
// ignore_for_file: avoid-substring

part of '../mac_address.dart';

// The canonical form: the stripped digits re-joined in pairs with a colon.
String _colonSeparated(String hex) => Iterable.generate(
  hex.length ~/ hexDigitsPerByte,
  (octet) => hex.substring(octet * hexDigitsPerByte, (octet + 1) * hexDigitsPerByte),
).join(_colon);

// One anchored alternative per notation, so a spelling that mixes separators matches none. The bare
// form takes digits in pairs, so an odd count fails the shape rather than miscounting.
final _notation = RegExp(
  '^(?:[0-9a-f]{2}(?::[0-9a-f]{2})*' // colon
  '|[0-9a-f]{2}(?:-[0-9a-f]{2})*' // hyphen
  r'|[0-9a-f]{4}(?:\.[0-9a-f]{4})*' // Cisco dot-quad
  r'|(?:[0-9a-f]{2})+)$', // bare hex
);

final _separators = RegExp('[-:.]');

const _colon = ':';
// The 2 widths IEEE 802 addresses come in: 48-bit (Ethernet, Wi-Fi) and 64-bit (802.15.4).
const _octetCounts = {6, 8};
// 3 octets of 2 hex digits, with the 2 colons between them.
const _prefix24Length = 8;
const _individualGroupBit = 0x01;
const _universalLocalBit = 0x02;
