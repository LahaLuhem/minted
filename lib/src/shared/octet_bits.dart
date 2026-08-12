/// The bit width of one octet, shared by the address arithmetic that counts in octets.
///
/// An octet is 8 bits by definition, so the two callers cannot drift apart the way `Iban` and
/// `Issn`'s coincidental group sizes can.
const bitsPerOctet = 8;
