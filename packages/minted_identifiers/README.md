# minted_identifiers

Standardised identifiers as well-modelled value types.

Part of the [minted](https://github.com/LahaLuhem/minted) family: pure-Dart value types
built on *parse, don't validate*, so anything that came through the parser is well-formed
by construction.

Holds `Uuid`, `Isbn`, `Issn`, `Isni`, `Imei`, `Gtin`.

Every value it hands you is well-formed by construction: build one through `parse`, which
returns a `ParseOutcome` carrying either the value or a typed failure, or `tryParse`, which
returns `null`. No door throws.

The shared vocabulary (`ParseOutcome`, `MintedFailure`, `Digit`, `Digits`, the `Uint` tower)
comes from [`minted`](https://pub.dev/packages/minted), which this package depends on. Take
only the domains you use: nothing here drags in another domain's engine.
