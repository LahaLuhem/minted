[![Pub Version](https://img.shields.io/pub/v/minted_constraints.svg)](https://pub.dev/packages/minted_constraints)
[![Pub Points](https://img.shields.io/pub/points/minted_constraints?logo=dart)](https://pub.dev/packages/minted_constraints/score)
[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/LahaLuhem/minted/blob/main/packages/minted_constraints/LICENSE)

# minted_constraints

Constraint types: primitives carrying a constraint, with no standard defining their text form.

Part of the [minted](https://github.com/LahaLuhem/minted) family: the building blocks the domain
types are cut from. Two groups, one idea — the character types a consumer reaches for directly, and
the numeric primitives every sibling shares.

## Install

```sh
dart pub add minted_constraints
```

## What's in the box

| Type                 | What it guarantees                                         |
|----------------------|------------------------------------------------------------|
| `Char`               | exactly one character a reader sees: one grapheme cluster  |
| `Letter`             | one `Char` whose base rune is a Unicode letter, any script |
| `Letters`            | one or more `Letter`s                                      |
| `AsciiChar`          | exactly one ASCII character                                |
| `AsciiAlphanumeric`  | one ASCII letter or digit                                  |
| `AsciiAlphanumerics` | one or more of those: a BIC code, a BBAN, an NSIN          |
| `AsciiLetter`        | exactly one ASCII letter, `A`-`Z`, `a`-`z`                 |
| `AsciiLetters`       | one or more of those                                       |
| `Digit` / `Digits`   | one decimal digit, or a sequence keeping its leading zeros |
| `Uint`               | never negative; a sign, not a width, so nothing wraps       |
| `NaturalNumber`      | `1` or more, where `Uint` allows zero                       |
| `Uint2` … `Uint32`   | one fixed machine width each, and the widths do not mix     |
| `Percentage`         | which unit you meant, so `15` and `0.15` cannot be swapped  |
| `Probability`        | `0` to `1` inclusive, both ends reported, not refused       |

A "single character" field is a `String` in almost every codebase, which means it accepts none and
accepts twenty. Every narrowing on the singulars is declared, so an `AsciiLetter` is an
`AsciiAlphanumeric`, an `AsciiChar`, a `Letter` and a `Char`, and passes wherever any of them is
wanted.

The plurals are extension types over `String` too, not `Iterable`s, because text is what they are:
string equality and printing are the behaviour you want. The elements are a getter away
(`letters`, `alphanumerics`).

Control characters are admitted rather than refused: a delimiter or a padding character is often one,
and a tab is a character by any reading. `AsciiChar.isControl` reports the narrower shape instead.

`Char` is a **grapheme cluster**, not a code unit or code point: a skin-toned thumbs-up is two code
points, a flag two, a joined family five. `length == 1` refuses all three and admits half a surrogate
pair. `Letter` narrows `Char` by the base rune, so `Ø` and a decomposed `é` qualify, an emoji does
not.

## A quick taste

```dart
AsciiChar.tryFrom('x')?.value;      // 'x'
AsciiChar.tryFrom('xy');            // null: two characters is not one
AsciiChar.tryFrom('\t')?.isControl; // true: a character, and it says which kind

AsciiLetter.tryFrom('Q')?.value;    // 'Q'
AsciiLetter.tryFrom('7');           // null: a digit is a character, but not a letter

final AsciiChar character = AsciiLetter.tryFrom('Q')!;   // the narrowing is declared

Char.tryFrom('👍🏽');    // one character: two code points, four code units
Char.tryFrom('ab');    // null: two characters
Char.tryFrom('\uD83D'); // null: half a surrogate pair is no character

Letter.tryFrom('Ø');   // a Danish initial, which AsciiLetter refuses
Letter.tryFrom('👍');   // null: one character, but no letter
```

The runnable version is the
[example](https://github.com/LahaLuhem/minted/blob/main/packages/minted_constraints/example/minted_constraints_example.dart).

## One shape, every type

- `tryFrom(value)` hands back the value, or `null` when the constraint does not hold
- no `parse` door, because no standard defines the text form of "one character"
- no failure vocabulary: one invariant leaves nothing a failure could say that `null` does not
- value equality and the printed form come from the representation, since each is an extension type

The [`minted` README](https://pub.dev/packages/minted) is the family guide.
