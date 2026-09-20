part of '../uuid.dart';

/// RFC 9562's 2 special [Uuid] values, and the 4 namespaces it registers.
abstract final class UuidConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// All zeros, RFC 9562's "no UUID here".
  static const nil = Uuid._('00000000-0000-0000-0000-000000000000');

  /// All ones, RFC 9562's top of a UUID range.
  static const max = Uuid._('ffffffff-ffff-ffff-ffff-ffffffffffff');

  // The namespaces RFC 9562 §6.6 registers for version 3 and 5. IANA takes more on request, so
  // these are the 4 registered rather than every one there can be.

  /// The DNS namespace, for hashing a domain name into a version 3 or 5 UUID.
  static const namespaceDns = Uuid._('6ba7b810-9dad-11d1-80b4-00c04fd430c8');

  /// The URL namespace.
  static const namespaceUrl = Uuid._('6ba7b811-9dad-11d1-80b4-00c04fd430c8');

  /// The ISO OID namespace.
  static const namespaceOid = Uuid._('6ba7b812-9dad-11d1-80b4-00c04fd430c8');

  /// The X.500 distinguished name namespace.
  static const namespaceX500 = Uuid._('6ba7b814-9dad-11d1-80b4-00c04fd430c8');
}
