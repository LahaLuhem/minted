## [Unreleased]
### Added
- \[#11\] Weekday added
- \[#4\] Isbn (ISO 2108: both generations, folded to ISBN-13)
- \[#1\] Bic (ISO 9362: SWIFT codes, 8- and 11-character forms folded to one value)
- \[#3\] PaymentCardNumber (ISO/IEC 7812: Luhn, masked rendering, card schemes reported)
- \[#16\] Gtin (GS1 GTIN: mod-10 across all four lengths, folded to fourteen digits)
- \[#17\]add Imei, validating the Luhn check the printed grouping hides
- \[#18\] Issn (ISO 3297: mod-11 check character, kept in printed NNNN-NNNC form)
- \[#19\] Isin (ISO 6166: Luhn over the letter-expanded number)
- \[#25\] Isni (ISO 27729: MOD 11-2, and ORCID iDs reported not gated)
- \[#26\] GeoCoordinate (ISO 6709: all three field widths, folded to decimal degrees)
- MacAddress (IEEE 802: 48- and 64-bit, four notations folded to one)
- Hostname (RFC 1123: LDH grammar, both length limits, ASCII only)
- IpAddress (RFC 5952 canonical form, v4 and v6, leading zeros refused)
- Cidr (RFC 4632: host bits refused, contains masks bits not text)
- \[#34\] Add Uint, NaturalNumber and the fixed-width Uint2 to Uint32 constraint types

### Changed
- \[#18\] Take Digits rather than String for digits-only assembly-factory parts

## [1.0.0] - 2026-08-09
### Changed
- \[#8\] Replace the throwing parse with ParseOutcome and per-type failures

## [0.0.2] - 2026-07-07
### Added
- \#5 Date + Month
- \#2 UUID

## [0.0.1] - 2026-07-06
### Added
- Email
- IBAN
- PhoneNumber
- Digit
- Digits

[Unreleased]: https://github.com/LahaLuhem/minted/compare/1.0.0...HEAD
[1.0.0]: https://github.com/LahaLuhem/minted/compare/0.0.2...1.0.0
[0.0.2]: https://github.com/LahaLuhem/minted/compare/0.0.1...0.0.2
[0.0.1]: https://github.com/LahaLuhem/minted/releases/tag/0.0.1
