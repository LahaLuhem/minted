import 'package:minted/minted.dart';

/// A transport-layer port number, `0` to `65535`.
/// Standard: [RFC 6335](https://www.rfc-editor.org/rfc/rfc6335).
///
/// Parse, don't validate: a port travels beside a host in every connection string, and the bound
/// goes unchecked until a socket call fails.
///
/// Exactly [Uint16]'s range, so that type owns the bound. `implements Uint16` lets a `Port` go
/// wherever a `Uint16` is wanted, never the reverse. Still its own type, because a width is not a
/// domain: an IPv6 hextet is `0`-`65535` too.
///
/// > [!NOTE]
/// > Port `0` is accepted, and [isWildcard] says so: it names no destination.
///
/// [value] is the numeric value; the string form is `value.toString()`.
///
/// {@example /example/minted_network_example.dart#port}
extension type const Port._(int value) implements Uint16 {
  /// The [Port] with numeric [value], or `null` unless it is in `0`-`65535`.
  static Port? tryFrom(int value) => Uint16.tryFrom(value) == null ? null : ._(value);

  /// Which RFC 6335 range this port falls in.
  PortRange get range => switch (value) {
    <= _systemCeiling => .system,
    <= _userCeiling => .user,
    _ => .dynamic,
  };

  /// Whether this is port `0`, which asks the OS to pick a free port on `bind`. RFC 6335 gives it no
  /// name of its own, listing it among the reserved edge values.
  bool get isWildcard => value == _wildcard;

  static const _wildcard = 0;
  static const _systemCeiling = 1023;
  static const _userCeiling = 49151;
}

/// Which RFC 6335 range a [Port] falls in. Derived from a port that already parsed, so it is a
/// classification rather than a value type: no parse door of its own.
enum PortRange {
  /// System (well-known) ports, `0`-`1023`. Assignment needs IANA review.
  system,

  /// User (registered) ports, `1024`-`49151`. Assigned by IANA on request.
  user,

  /// Dynamic (private, ephemeral) ports, `49152`-`65535`. Never assigned.
  dynamic,
}
