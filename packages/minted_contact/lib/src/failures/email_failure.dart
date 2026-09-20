/// @docImport '../email.dart';
library;

import 'package:minted/minted.dart';

/// Why an [Email] refused its input. One variant is the ceiling, not a shortcut, since `email_validator`
/// exposes a single `bool` and a finer diagnosis would be a guess.
enum EmailFailure(@override final String message) implements MintedFailure {
  /// The input isn't a well-formed RFC 5322 address.
  malformed('not a well-formed email address');

  @override
  String get typeName => 'Email';
}
