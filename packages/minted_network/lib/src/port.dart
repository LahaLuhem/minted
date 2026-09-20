import 'package:minted_constraints/minted_constraints.dart';

/// A transport-layer port number, `0` to `65535`.
/// Standard: [RFC 6335](https://www.rfc-editor.org/rfc/rfc6335).
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

  // Grouped by who named them, not by band, since `range` reads the band back anyway.
  //========================================== RESERVED ==========================================//

  /// Port `0`, which asks the OS to pick a free port on `bind`.
  static const wildcard = Port._(0);

  //====================================== IANA-REGISTERED =======================================//
  // The service registry carries each of these under the same name.

  /// FTP's data channel. RFC 959.
  static const ftpData = Port._(20);

  /// FTP's control channel. RFC 959.
  static const ftp = Port._(21);

  /// Secure Shell. RFC 4253.
  static const ssh = Port._(22);

  /// Telnet. RFC 854.
  static const telnet = Port._(23);

  /// Simple Mail Transfer. RFC 5321.
  static const smtp = Port._(25);

  /// DNS. The registry files it as `domain`, which is nobody's name for it. RFC 1035.
  static const dns = Port._(53);

  /// Default HTTP port. RFC 9110.
  static const http = Port._(80);

  /// Post Office Protocol v3. RFC 1939.
  static const pop3 = Port._(110);

  /// Network Time Protocol. RFC 5905.
  static const ntp = Port._(123);

  /// Internet Message Access Protocol. RFC 9051.
  static const imap = Port._(143);

  /// HTTP over TLS. RFC 9110.
  static const https = Port._(443);

  /// MySQL, registered by its own authors.
  static const mysql = Port._(3306);

  /// PostgreSQL, registered by its own authors.
  static const postgresql = Port._(5432);

  /// Redis, registered by its own authors.
  static const redis = Port._(6379);

  /// HTTP alternate, registered as `http-alt`.
  static const httpAlt = Port._(8080);

  /// MongoDB, registered by its own authors.
  static const mongodb = Port._(27017);

  //======================================== CONVENTIONAL ========================================//
  // Our names, not IANA's: each of these is registered to some other service. Widespread, not standard,
  // so treat a match as a hint rather than proof of what is listening.

  /// The Node dev-server habit, out of create-react-app and Express. IANA has 3000 as `hbci`.
  static const nodeDev = Port._(3000);

  /// Flask's dev server default. IANA has 5000 as `commplex-main`.
  static const flask = Port._(5000);

  /// Django's dev server default. IANA has 8000 as `irdmi`.
  static const django = Port._(8000);

  /// Where a dev TLS server usually lands. IANA has 8443 as `pcsync-https`.
  static const httpsAlt = Port._(8443);

  /// PHP-FPM's default pool address. IANA has 9000 as `cslistener`.
  static const phpFpm = Port._(9000);
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
