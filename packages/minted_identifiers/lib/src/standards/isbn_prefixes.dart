/// The GS1 prefix ranges ISO 2108 assigns to books, and the one range carved out of them.
///
/// Shared because `Isbn` gates on these and `IsbnInvalidPrefix` names them in its message, and a
/// failure may not import its own value type (see `AGENTS.md`, repo layout). Not a registry: these
/// four constants are fixed by the standard, unlike the hyphenation range table
/// (`/APPENDIX.md#registry-data-ships-a-clock`).
library;

/// The original Bookland prefix, and the only one with a ten-digit equivalent.
const bookland978 = '978';

/// The second Bookland prefix, added when `978` began to run out.
const bookland979 = '979';

/// Both prefixes ISO 2108 gives to books.
const booklandPrefixes = {bookland978, bookland979};

/// ISO 10957 holds `979-0` for the ISMN, so printed music is carved out of the `979` range. Four
/// digits, not three, because it is a sub-range.
const ismnRange = '9790';
