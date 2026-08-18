[![Pub Version](https://img.shields.io/pub/v/minted_constraints.svg)](https://pub.dev/packages/minted_constraints)
[![Pub Points](https://img.shields.io/pub/points/minted_constraints?logo=dart)](https://pub.dev/packages/minted_constraints/score)
[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/LahaLuhem/minted/blob/main/packages/minted_constraints/LICENSE)

# minted_constraints

Constraint types: primitives carrying a constraint, with no standard defining their text form.

Part of the [minted](https://github.com/LahaLuhem/minted) family. These are the building blocks the
domain types are cut from, so **nothing here depends on `package:minted`**: take it alone and you
never meet the outcome machinery.

## Install

```sh
dart pub add minted_constraints
```

## What's in the box

| Type          | What it guarantees                       |
|---------------|------------------------------------------|
| `AsciiChar`   | exactly one ASCII character              |
| `AsciiLetter` | exactly one ASCII letter, `A`-`Z`, `a`-`z` |

A "single character" field is a `String` in almost every codebase, which means it accepts none and
accepts twenty. `AsciiLetter` narrows that to what the standards-bound codes admit, and declares the
narrowing, so a letter passes anywhere a character is wanted.

Control characters are admitted rather than refused: a delimiter or a padding character is often one,
and a tab is a character by any reading. `AsciiChar.isControl` reports the narrower shape instead.

## A quick taste

```dart
AsciiChar.tryFrom('x')?.value;      // 'x'
AsciiChar.tryFrom('xy');            // null: two characters is not one
AsciiChar.tryFrom('\t')?.isControl; // true: a character, and it says which kind

AsciiLetter.tryFrom('Q')?.value;    // 'Q'
AsciiLetter.tryFrom('7');           // null: a digit is a character, but not a letter

final AsciiChar character = AsciiLetter.tryFrom('Q')!;   // the narrowing is declared
```

The runnable version is the
[example](https://github.com/LahaLuhem/minted/blob/main/packages/minted_constraints/example/minted_constraints_example.dart).

## One shape, every type

- `tryFrom(value)` hands back the value, or `null` when the constraint does not hold
- no `parse` door, because no standard defines the text form of "one character"
- no failure vocabulary: one invariant leaves nothing a failure could say that `null` does not
- value equality and the printed form come from the representation, since each is an extension type

The [`minted` README](https://pub.dev/packages/minted) is the family guide.
