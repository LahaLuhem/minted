[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![Coverage Status](https://coveralls.io/repos/github/LahaLuhem/minted/badge.svg?branch=main)](https://coveralls.io/github/LahaLuhem/minted?branch=main)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/LahaLuhem/minted/pulls)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](./LICENSE)

# minted

Monorepo for **minted**: pure-Dart value types for the values you'd usually keep in a `String` and
hope for the best. Built on *parse, don't validate*, so the parser is the only door in and anything
that came through it is well-formed by construction.

## Packages

| Package | What it holds | pub.dev |
|---|---|---|
| [`minted`](./packages/minted) | Core: outcomes, `Digit`/`Digits`, the `Uint` family, `Percentage`, `Probability` | [![Pub Version](https://img.shields.io/pub/v/minted.svg)](https://pub.dev/packages/minted) |
| [`minted_chronology`](./packages/minted_chronology) | `Date`, `Month`, `Weekday`, `Iso8601Duration` | not yet published |
| [`minted_contact`](./packages/minted_contact) | `Email`, `PhoneNumber` | not yet published |
| [`minted_finance`](./packages/minted_finance) | `Iban`, `Bic`, `Isin`, `PaymentCardNumber` | not yet published |
| [`minted_geography`](./packages/minted_geography) | `GeoCoordinate` | not yet published |
| [`minted_identifiers`](./packages/minted_identifiers) | `Uuid`, `Isbn`, `Issn`, `Isni`, `Imei`, `Gtin` | not yet published |
| [`minted_network`](./packages/minted_network) | `IpAddress`, `Cidr`, `Hostname`, `DnsName`, `MacAddress`, `Port` | not yet published |

> **The siblings are scaffolds.** Every type still ships in `minted` today; the packages exist so
> the workspace tooling and release pipeline are proven before the types move at 3.0.0. There is
> also a private `minted_conformance` member holding the cross-package suites, which never ships.

**[`packages/minted/README.md`](./packages/minted/README.md) is the documentation you actually
want**: the pub.dev landing page, with the type catalogue and usage guide. This file is the map.

## Working in this repo

It is a [pub workspace](https://dart.dev/tools/pub/workspaces): one resolution, one root
`pubspec.lock`, shared by every member.

```bash
dart pub get             # once at the root; resolves every member
dart run melos run       # lists what you can run
dart run melos run test  # every member's suite, fanned out
```

[Melos](https://melos.invertase.dev) saves you remembering which commands are workspace-wide and
which are per-package: `analyze` and `format` run once at the root, `test` and `coverage` fan out.
Releases stay with [`scripts/release.sh`](./scripts/README.md).

Plain commands work too, but mind the split: `analyze` and `format` want the root, while anything
reading one pubspec (`dart test`, `cider`, `dart pub publish`) wants `packages/minted`.

Contributor docs live at the root because they cover every package: [AGENTS.md](./AGENTS.md) for
hard rules and repo layout, [CODESTYLE.md](./CODESTYLE.md) for style, and
[APPENDIX.md](./APPENDIX.md) for why things are the way they are. Releases go through
[`scripts/release.sh`](./scripts/README.md).
