/// @docImport '../email.dart';
library;

import 'package:minted/minted.dart';

/// Why an [Email] refused its input. One variant, and that is the ceiling, not a shortcut:
/// `email_validator` exposes a single `bool`, so a finer diagnosis would be a guess.
enum EmailFailure implements MintedFailure {
  /// The input is not a well-formed RFC 5322 address.
  malformed('not a well-formed email address');

  new(this.message);

  @override
  final String message;

  @override
  String get typeName => 'Email';
}
