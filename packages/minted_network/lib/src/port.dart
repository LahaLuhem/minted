import 'package:minted_constraints/minted_constraints.dart';

part 'constants/port_constants.dart';

/// A transport-layer port number, `0` to `65535`.
/// Standard: [RFC 6335](https://www.rfc-editor.org/rfc/rfc6335).
///
/// Without the type the bound goes unchecked until a socket call fails.
///
/// Exactly [Uint16]'s range, so that type owns the bound, and `implements Uint16` lets a `Port` go wherever
/// a `Uint16` is wanted, never the reverse.
///
/// Named values: [PortConstants].
///
/// {@example /example/minted_network_example.dart#port}
extension type const Port._(int value) implements Uint16 {
  /// The [Port] with numeric [value], or `null` unless it's in `0`-`65535`.
  static Port? tryFrom(int value) => Uint16.tryFrom(value) == null ? null : ._(value);

  /// Which RFC 6335 range this port falls in.
  PortRange get range => switch (value) {
    <= _systemCeiling => .system,
    <= _userCeiling => .user,
    _ => .dynamic,
  };

  /// Whether this is [PortConstants.wildcard].
  bool get isWildcard => value == PortConstants.wildcard;

  static const _systemCeiling = 1023;
  static const _userCeiling = 49151;
}

/// Which RFC 6335 range a [Port] falls in.
enum PortRange() {
  /// System (well-known) ports, `0`-`1023`. Assignment needs IANA review.
  system,

  /// User (registered) ports, `1024`-`49151`. Assigned by IANA on request.
  user,

  /// Dynamic (private, ephemeral) ports, `49152`-`65535`. Never assigned.
  dynamic,
}
