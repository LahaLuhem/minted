import 'package:minted/minted.dart';

/// A failure vocabulary, standing in for the one a real value type carries in its own package.
enum EvenLengthFailure(@override final String message) implements MintedFailure {
  /// The input cannot be halved, so there is nothing to hand back.
  odd('the character count is odd');

  @override
  String get typeName => 'EvenLength';
}
