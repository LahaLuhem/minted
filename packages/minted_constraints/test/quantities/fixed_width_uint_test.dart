// Test file
// ignore_for_file: prefer-match-file-name

import 'dart:math';

import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('the fixed-width unsigned integers', () {
    // One table over all five widths. Each row carries the bit count, the ceiling it implies, and a
    // door handing back the numeric value, so the boundary checks run identically against each type.
    final widths = <String, ({int bits, int max, int? Function(int value) valueFrom})>{
      'Uint2': (bits: 2, max: 3, valueFrom: (value) => Uint2.tryFrom(value)?.value),
      'Uint4': (bits: 4, max: 15, valueFrom: (value) => Uint4.tryFrom(value)?.value),
      'Uint8': (bits: 8, max: 255, valueFrom: (value) => Uint8.tryFrom(value)?.value),
      'Uint16': (bits: 16, max: 65535, valueFrom: (value) => Uint16.tryFrom(value)?.value),
      'Uint32': (bits: 32, max: 4294967295, valueFrom: (value) => Uint32.tryFrom(value)?.value),
    };

    scenarioOutline<({int bits, int max, int? Function(int value) valueFrom})>(
      'each width accepts its whole range and refuses either side of it',
      examples: widths,
      outline: (example) {
        // Ties the ceiling to the bit count in the type's own name, so a 65535 typed into Uint32
        // fails here rather than shipping.
        check(example.max).equals(pow(2, example.bits).toInt() - 1);

        check(example.valueFrom(0)).equals(0);
        check(example.valueFrom(example.max)).equals(example.max);
        check(example.valueFrom(example.max + 1)).isNull();
        check(example.valueFrom(-1)).isNull();
      },
    );
  });
}
