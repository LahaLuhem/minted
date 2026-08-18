## [Unreleased]
### Changed
- Add GeoBounds and type the geography doors with Latitude and Longitude

## [3.1.0] - 2026-08-18
### Changed
- minted\_constraints: the primitives move out of core, plus Char / Letter / Alphanumeric

## [3.0.1] - 2026-08-17
### Changed
- README is the family landing page now: install per domain package, and the catalogue says which package holds each type

### Fixed
- the README's `Date.of` snippets unwrap the outcome they return, so they compile as written

## [3.0.0] - 2026-08-16
### Removed
- \[#60\] Split minted into a pub workspace of domain packages

## [2.0.0] - 2026-08-14
### Changed
- nothing throws: every fallible door returns a ParseOutcome
- assembly factories return ParseOutcome instead of throwing, all 20 of them
- MintedFormatException is now MintedFormatError, an Error, so on FormatException no longer catches it
- Isbn and Imei return Digits from their digit-part getters, so the parts round-trip into fromComponents
- Date.of and Date.fromDateTime report DateComponentFailure, the parts-only subset

### Removed
- the doors 1.1.0 deprecated: Digit and Digits parse/tryParse/from, Month.from, Weekday.from, Date.addDays/subtractDays, Date(y, m, d), Email.fromDomainLabels
- DigitFailure, DigitsFailure and WeekdayFailure, which no door produces any more

## [1.1.0] - 2026-08-14
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
- \[#33\] Add Port, a 0-65535 port number
- Add Iso8601Duration, an ISO 8601 duration with months and years
- \[#32\] Add Percentage
- \[#35\] Add Probability, 0 to 1 with both ends included
- \[#45\] Add DnsName, the permissive RFC 2181 counterpart to Hostname

### Changed
- \[#18\] Take Digits rather than String for digits-only assembly-factory parts
- Bump to Dart 3.13 + add verifiable dartdoc examples for every type, with a CI gate

### Deprecated
- deprecate every door v2 removes, and add the replacements they point at

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

[Unreleased]: https://github.com/LahaLuhem/minted/compare/minted-3.1.0...minted-HEAD
[3.1.0]: https://github.com/LahaLuhem/minted/compare/minted-3.0.1...minted-3.1.0
[3.0.1]: https://github.com/LahaLuhem/minted/compare/minted-3.0.0...minted-3.0.1
[3.0.0]: https://github.com/LahaLuhem/minted/compare/minted-2.0.0...minted-3.0.0
[2.0.0]: https://github.com/LahaLuhem/minted/compare/1.1.0...2.0.0
[1.1.0]: https://github.com/LahaLuhem/minted/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/LahaLuhem/minted/compare/0.0.2...1.0.0
[0.0.2]: https://github.com/LahaLuhem/minted/compare/0.0.1...0.0.2
[0.0.1]: https://github.com/LahaLuhem/minted/releases/tag/0.0.1
