import 'package:minted_constraints/minted_constraints.dart';

/// A transport-layer port number, `0` to `65535`. Standard: [RFC 6335](https://www.rfc-editor.org/rfc/rfc6335)
/// .
///
/// Without the type the bound goes unchecked until a socket call fails.
///
/// Exactly [Uint16]'s range, so that type owns the bound, and `implements Uint16` lets a `Port` go wherever
/// a `Uint16` is wanted, never the reverse.
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

  /// Whether this is [wildcard].
  bool get isWildcard => value == wildcard;

  static const _systemCeiling = 1023;
  static const _userCeiling = 49151;

  ///////////////////////////////////////////// SYSTEM /////////////////////////////////////////////

  /// Port `0`, which asks the OS to pick a free port on `bind`.
  static const wildcard = Port._(0);
  static const ftpData = Port._(20);
  static const ftp = Port._(21);

  /// Secure Shell. RFC 4253.
  static const ssh = Port._(22);

  static const telnet = Port._(23);
  static const smtp = Port._(25);
  static const dns = Port._(53);

  /// Default HTTP port. RFC 9110.
  static const http = Port._(80);

  static const pop3 = Port._(110);
  static const ntp = Port._(123);
  static const imap = Port._(143);

  /// HTTP over TLS. RFC 9110.
  static const https = Port._(443);

  ////////////////////////////////////////////// USER //////////////////////////////////////////////
  /// HTTP alternate. Officially registered with IANA.
  static const httpAlt = Port._(8080);

  static const mysql = Port._(3306);
  static const postgresql = Port._(5432);
  static const redis = Port._(6379);

  /// IANA-registered as `pcsync-https`, but widely used as HTTPS-alt.
  static const httpsAlt = Port._(8443);

  //////////////////////////////////////////// CONVENTION ///////////////////////////////////////////
  static const nodeDev = Port._(3000);

  /// Flask default. No standard.
  static const flask = Port._(5000);

  /// Django default. No standard.
  static const django = Port._(8000);

  /// PHP-FPM default. No standard.
  static const phpFpm = Port._(9000);

  /// MongoDB default. No IANA registration for MongoDB.
  static const mongodb = Port._(27017);
}

/// Which RFC 6335 range a [Port] falls in.
enum PortRange {
  /// System (well-known) ports, `0`-`1023`. Assignment needs IANA review.
  system,

  /// User (registered) ports, `1024`-`49151`. Assigned by IANA on request.
  user,

  /// Dynamic (private, ephemeral) ports, `49152`-`65535`. Never assigned.
  dynamic,
}
