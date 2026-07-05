---
name: Bug report
about: A type accepts input it should reject, rejects input it should accept, or misbehaves
title: "[BUG]"
labels: ''
assignees: ''

---

**Which type**
e.g. `Iban`, `Email`, `CreditCardNumber`.

**What happened**
A clear and concise description of the bug.

**Minimal reproduction**
The exact input string and the call, plus what you got back:

```dart
final result = Iban.tryParse('GB82 WEST 1234 5698 7654 32');
// expected: a valid Iban
// got: null
```

**Expected behaviour**
What should `parse` / `tryParse` (or the helper) have returned?

**Standard reference (if relevant)**
Link or cite the clause of the standard (ISO / RFC / GS1 / ITU) that says your
input is or is not valid — this makes the fix unambiguous.

**Environment**
 - `minted` version: [e.g. 0.1.0]
 - Dart SDK: [`dart --version`]
 - Runtime: [Flutter / Dart server / CLI / web]

**Additional context**
Anything else worth knowing.
