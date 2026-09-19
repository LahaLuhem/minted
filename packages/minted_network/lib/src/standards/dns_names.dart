/// The DNS rules `Hostname` and `DnsName` both enforce, in one place so the strict type and the permissive
/// one can't drift on a limit or on how a trailing root dot folds.
library;

/// The character between labels.
const labelSeparator = '.';

/// The most characters one label may hold (RFC 1035 §2.3.4, RFC 2181 §11).
const maxLabelLength = 63;

/// The most characters a whole name may hold. 253, not RFC 1035's 255, because the wire form spends
/// a length octet per label plus a null for the root.
const maxNameLength = 253;

/// [lowerInput] with one trailing root dot dropped, which RFC 3696 §2 makes applications accept. A bare
/// `.` is left be, so it fails as an empty label rather than becoming the empty string.
String rootStripped(String lowerInput) =>
    lowerInput.length > labelSeparator.length && lowerInput.endsWith(labelSeparator)
    // one trailing '.' is a BMP code unit, never half a surrogate pair, so this cannot split one
    // ignore: avoid-substring
    ? lowerInput.substring(0, lowerInput.length - labelSeparator.length)
    : lowerInput;

/// Whether [character] sits outside ASCII, so the name may be internationalised and wants punycode rather
/// than a character fix.
bool isNonAscii(String character) => character.codeUnitAt(0) > _lastAscii;

const _lastAscii = 0x7f;
