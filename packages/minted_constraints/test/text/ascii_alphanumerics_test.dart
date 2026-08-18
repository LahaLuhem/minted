import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('AsciiAlphanumerics', () {
    scenarioOutline<({String input, String? accepted})>(
      'tryFrom takes one or more ASCII letters and digits',
      examples: {
        'letters alone': (input: 'NWBK', accepted: 'NWBK'),
        'digits alone': (input: '6016', accepted: '6016'),
        // A BBAN, which is exactly what this type exists to hold.
        'a mix': (input: 'NWBK60161331926819', accepted: 'NWBK60161331926819'),
        'a space among them, as a grouped BBAN would carry': (input: 'NWBK 6016', accepted: null),
        'punctuation': (input: 'NWBK-6016', accepted: null),
        'an empty string': (input: '', accepted: null),
      },
      outline: (example) {
        check(AsciiAlphanumerics.tryFrom(example.input)?.value).equals(example.accepted);
      },
    );

    scenario('alphanumerics hands back one element per code unit', () {
      check(AsciiAlphanumerics.tryFrom('G1')!.alphanumerics.map((part) => part.value).toList())
          .deepEquals(['G', '1']);
    });
  });
}
