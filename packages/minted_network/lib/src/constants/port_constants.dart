part of '../port.dart';

/// The [Port] numbers IANA registered, plus the dev-server defaults convention settled on.
// Grouped by who named them, not by band, since `range` reads the band back anyway.
abstract final class PortConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

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
