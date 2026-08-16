/// The DNS rules `Hostname` and `DnsName` both enforce, in one place so the strict type and the
/// permissive one cannot drift on a limit or on how a trailing root dot folds.
///
/// Public within `lib/src/` and never re-exported from `lib/minted.dart`: top-level `_` names are
/// library-private in Dart, so sharing them at all means dropping the underscore.
library;

/// The character between labels.
const labelSeparator = '.';

/// The most characters one label may hold (RFC 1035 §2.3.4, RFC 2181 §11).
const maxLabelLength = 63;

/// The most characters a whole name may hold. 253, not RFC 1035's 255: the wire form spends a
/// length octet per label plus a null for the root, so presentation form is two shorter.
const maxNameLength = 253;

/// [lowerInput] with one trailing root dot dropped, which RFC 3696 §2 requires applications to
/// accept. A bare `.` is left be, so it fails as an empty label rather than becoming the empty
/// string.
String rootStripped(String lowerInput) =>
    lowerInput.length > labelSeparator.length && lowerInput.endsWith(labelSeparator)
    // it drops exactly one trailing '.', a BMP code unit that can never be half a surrogate pair, so the slice cannot split a character.
    // ignore: avoid-substring
    ? lowerInput.substring(0, lowerInput.length - labelSeparator.length)
    : lowerInput;

/// Whether [character] sits outside ASCII, so the name may be internationalised and wants punycode
/// rather than a character fix.
bool isNonAscii(String character) => character.codeUnitAt(0) > _lastAscii;

const _lastAscii = 0x7f;
