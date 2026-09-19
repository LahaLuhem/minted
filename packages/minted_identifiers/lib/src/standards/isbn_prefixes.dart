/// The GS1 prefix ranges ISO 2108 gives to books, plus the one range carved out of them.
///
/// Shared because `Isbn` gates on these and `IsbnInvalidPrefix` names them, and a failure may not import
/// its own value type (`AGENTS.md`, repo layout). Fixed by the standard, unlike the hyphenation range
/// table (`/APPENDIX.md#registry-data-ships-a-clock`).
library;

/// The original Bookland prefix, and the only one with a 10-digit form.
const bookland978 = '978';

/// The 2nd Bookland prefix, added when `978` started running out.
const bookland979 = '979';

/// Both prefixes ISO 2108 gives to books.
const booklandPrefixes = {bookland978, bookland979};

/// ISO 10957 holds `979-0` for the ISMN, so printed music is carved out of `979`. 4 digits, not 3,
/// because it's a sub-range.
const ismnRange = '9790';
