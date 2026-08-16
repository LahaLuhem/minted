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
| [`minted`](./packages/minted) | Every value type, and the `ParseOutcome` vocabulary they share | [![Pub Version](https://img.shields.io/pub/v/minted.svg)](https://pub.dev/packages/minted) |

**[`packages/minted/README.md`](./packages/minted/README.md) is the documentation you actually
want** — it is the pub.dev landing page, with the type catalogue and the usage guide. This file is
just the map.

## Working in this repo

It is a [pub workspace](https://dart.dev/tools/pub/workspaces): one resolution, one root
`pubspec.lock`, shared by every member.

```bash
dart pub get             # once at the root; resolves every member
dart run melos run       # lists what you can run
dart run melos run test  # every member's suite, fanned out
```

[Melos](https://melos.invertase.dev) is the entrypoint so you don't have to remember which commands
are workspace-wide and which are per-package: `analyze` and `format` run once from the root, `test`
and `coverage` fan out over the members. It is a script runner here and nothing more, since releases
go through `cider` and [`scripts/release.sh`](./scripts/README.md).

The plain commands still work if you prefer them. Just note that `analyze` and `format` want the
root, while anything reading a single pubspec (`dart test`, `cider`, `dart pub publish`,
`dependency_validator`) wants the member, via `cd packages/minted` or `dart pub -C packages/minted`.

Contributor docs live at the root because they cover every package: [AGENTS.md](./AGENTS.md) for
hard rules and repo layout, [CODESTYLE.md](./CODESTYLE.md) for style, and
[APPENDIX.md](./APPENDIX.md) for why things are the way they are. Releases go through
[`scripts/release.sh`](./scripts/README.md).
